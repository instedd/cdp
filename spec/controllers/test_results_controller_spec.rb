require 'spec_helper'
require 'policy_spec_helper'

describe TestResultsController, elasticsearch: true do
  setup_fixtures do
    @user = User.make!
    @institution = Institution.make! user: @user

    @root_location = Location.make!
    @location = Location.make! parent: @root_location
    @site = Site.make! institution: @institution, location: @location
    @subsite = Site.make! institution: @institution, location: @location, parent: @site
    @device = Device.make! institution: @institution, site: @site

    @site2 = Site.make! institution: @institution, location: @location
    @device2 = Device.make! institution: @institution, site: @site2

    @other_institution = Institution.make!
    @other_user = @other_institution.user
    @other_site = Site.make! institution: @other_institution
    @other_device = Device.make! institution: @other_institution, site: @other_site
  end

  before(:each) {sign_in user}
  let(:default_params) { {context: institution.uuid} }

  it "should display an empty page when there are no test results" do
    response = get :index
    expect(response.status).to eq(200)
  end

  it "should list test results" do
    test_result = TestResult.create_and_index(
      core_fields: {"assays" =>["condition" => "mtb", "result" => :positive]},
      device_messages: [ DeviceMessage.make!(device: device) ])

    get :index
    expect(response).to be_success
    expect(assigns(:tests).map{|t| t['test']['uuid']}).to contain_exactly(test_result.uuid)
  end

  context "scoping" do
    it "should show all tests for institution" do
      user.update_attribute(:last_navigation_context, institution.uuid)

      test_result = TestResult.create_and_index(
      core_fields: {"assays" =>["condition" => "mtb", "result" => :positive]},
      device_messages: [ DeviceMessage.make!(device: device) ])

      get :index, params: { context: site.uuid }
      expect(assigns(:tests).map{|t| t['test']['uuid']}).to contain_exactly(test_result.uuid)
    end

    it "with exclusion should show no tests (devices with no site can't have tests)" do
      test_result = TestResult.create_and_index device: device

      get :index, params: { context: institution.uuid+"-!" }
      expect(assigns(:tests)).to be_empty
    end

    it "should show all tests for site" do
      user.update_attribute(:last_navigation_context, site.uuid)
      device2 = Device.make! institution: institution, site: subsite

      test_result = TestResult.create_and_index device: device
      test_result_subsite = TestResult.create_and_index device: device2

      get :index, params: { context: site.uuid+"-*" }
      expect(assigns(:tests).map{|t| t['test']['uuid']}).to eq([test_result.uuid, test_result_subsite.uuid])
    end

    it "with exclusion should show only tests for site, not subsites" do
      device2 = Device.make! institution: institution, site: subsite

      test_result = TestResult.create_and_index device: device
      test_result_subsite = TestResult.create_and_index device: device2

      get :index, params: { context: site.uuid+"-!" }
      expect(assigns(:tests).map{|t| t['test']['uuid']}).to contain_exactly(test_result.uuid)
    end
  end

  context "loading entities" do
    before(:each) do
      other_user; other_institution; other_site; other_device
      subsite; site2; device2
      TestResult.create_and_index(
        core_fields: {"assays" =>["condition" => "mtb", "result" => :positive]},
        device_messages: [ DeviceMessage.make!(device: device) ])
    end

    it "should load for filters" do
      get :index
      expect(response).to be_success
      expect(assigns(:sites).to_a).to contain_exactly(site, site2, subsite)
      expect(assigns(:devices).to_a).to contain_exactly(device, device2)
    end

    it "should load for filters scoped by context" do
      get :index, params: { context: site.uuid }
      expect(response).to be_success
      expect(assigns(:sites).to_a).to contain_exactly(site, subsite)
      expect(assigns(:devices).to_a).to contain_exactly(device)
    end
  end

  context "CSV" do
    let!(:patient) do
      Patient.make!(
        institution: institution,
        core_fields: { "gender" => "male" },
        custom_fields: { "custom" => "patient value" },
        plain_sensitive_data: { "name": "Doe" }
      )
    end
    let!(:encounter) do
      Encounter.make!(
        institution: institution,
        patient: patient,
        core_fields: {
          "patient_age" => { "years" => 12 },
          "diagnosis" => [
            "name" => "mtb",
            "condition" => "mtb",
            "result" => "positive"
          ]
        },
        custom_fields: { "custom" => "encounter value" },
        plain_sensitive_data: { "observations": "HIV POS" }
      )
    end
    let!(:sample) do
      Sample.make!(
        institution: institution,
        encounter: encounter,
        patient: patient,
        core_fields: { "type" => "blood" },
        custom_fields: { "custom" => "sample value" }
      )
    end
    let!(:sample_id) { SampleIdentifier.make!(sample: sample) }
    let!(:test) do
      TestResult.make_from_sample(
        sample,
        device: device,
        core_fields: {
          "name" => "test1", "error_description" => "No error",
          "assays" => [
            { "condition" => "mtb", "result" => "positive", "name" => "mtb" },
            { "condition" => "flu", "result" => "negative", "name" => "flu" }
          ]
        },
        custom_fields: { "custom_a" => "test value 1" }
      ).tap { |t| TestResultIndexer.new(t).index(true) }
    end

    let(:csv) { CSV.parse(response.body, headers: true) }

    RSpec::Matchers.define :contain_field do |name, value|
      match do |csv_row|
        if value.blank?
          csv_row[name].blank?
        else
          csv_row[name] == value
        end
      end
      failure_message do |csv_row|
        "expected '#{name}' to eq '#{value}', got '#{csv_row[name]}'\nrow: #{csv_row.inspect}"
      end
    end

    context "single test" do
      before(:each) do
        get :index, format: :csv
      end

      it "should be successful" do
        expect(response).to be_success
      end

      it "should download a single test" do
        expect(csv.size).to eq(1)
      end

      it "should download core fields" do
        fields = { "Test uuid" => test.uuid, "Test name" => "test1", "Device uuid" => device.uuid, "Location id" => site.location.id,
          "Institution name" => institution.name, "Site name" => site.name, "Sample type" => "blood",
          "Encounter uuid" => encounter.uuid, "Patient gender" => "male" }
        fields.each do |name, value|
          expect(csv[0]).to contain_field(name, value)
        end
      end

      it "should download dynamic fields" do
        fields = { "Location admin levels admin level 0" => root_location.id, "Location admin levels admin level 1" => location.id }
        fields.each do |name, value|
          expect(csv[0]).to contain_field(name, value)
        end
      end

      it "should download multi fields" do
        fields = { "Sample uuid 1" => sample.uuids[0], "Sample uuid 2" => sample.uuids[1] }
        fields.each do |name, value|
          expect(csv[0]).to contain_field(name, value)
        end
      end

      it "should download multi nested fields" do
        fields = { "Test assays name 1" => "mtb", "Test assays condition 1" => "mtb", "Test assays result 1" => "positive",
          "Test assays name 2" => "flu", "Test assays condition 2" => "flu", "Test assays result 2" => "negative",
          "Encounter diagnosis name 1" => "mtb", "Encounter diagnosis condition 1" => "mtb", "Encounter diagnosis result 1" => "positive"}
        fields.each do |name, value|
          expect(csv[0]).to contain_field(name, value)
        end
      end

      it "should download custom fields" do
        fields = { "Test custom a" => "test value 1", "Sample custom" => "sample value", "Encounter custom" => "encounter value", "Patient custom" => "patient value" }
        fields.each do |name, value|
          expect(csv[0]).to contain_field(name, value)
        end
      end

      it "should not download pii fields" do
        fields = { "Patient name" => "Doe", "Encounter observations" => "HIV POS" }
        fields.each do |name, value|
          expect(csv.headers).to_not include(name)
          expect(csv[0]).to_not include(value)
        end
      end

      it "should format duration fields" do
        expect(csv[0]).to contain_field("Encounter patient age", "12 years")
      end

    end

    context "multiple tests" do

      it "should merge multi and custom fields" do
        test2 = TestResult.make_from_sample(sample, core_fields: {"assays" =>["condition" => "inh", "result" => "negative", "name" => "inh"]}, custom_fields: {"custom_b" => "test value 2"}).tap {|t| TestResultIndexer.new(t).index(true)}
        get :index, format: :csv
        expect(csv.size).to eq(2)

        fields1 = { "Test assays name 1" => "mtb", "Test assays condition 1" => "mtb", "Test assays result 1" => "positive",
          "Test assays name 2" => "flu", "Test assays condition 2" => "flu", "Test assays result 2" => "negative",
          "Encounter diagnosis name 1" => "mtb", "Encounter diagnosis condition 1" => "mtb", "Encounter diagnosis result 1" => "positive",
          "Test custom a" => "test value 1", "Test custom b" => "", "Sample custom" => "sample value", "Encounter custom" => "encounter value", "Patient custom" => "patient value"}
        fields1.each do |name, value|
          expect(csv[0]).to contain_field(name, value)
        end

        fields2 = { "Test assays name 1" => "inh", "Test assays condition 1" => "inh", "Test assays result 1" => "negative",
          "Test assays name 2" => "", "Test assays condition 2" => "", "Test assays result 2" => "",
          "Encounter diagnosis name 1" => "mtb", "Encounter diagnosis condition 1" => "mtb", "Encounter diagnosis result 1" => "positive",
          "Test custom a" => "", "Test custom b" => "test value 2", "Sample custom" => "sample value", "Encounter custom" => "encounter value", "Patient custom" => "patient value"}
        fields2.each do |name, value|
          expect(csv[1]).to contain_field(name, value)
        end
      end

    end

  end

  describe "show single test result" do

    let!(:owner) { User.make! }
    let!(:institution) { Institution.make! user: owner }
    let!(:site)  { Site.make! institution: institution }
    let!(:device) { Device.make! institution: institution, site: site }

    let!(:test_result) do
      TestResult.create_and_index(
        core_fields: {"assays" =>["condition" => "mtb", "result" => :positive]},
        device_messages: [ DeviceMessage.make!(device: device) ]
      )
    end

    let!(:user) { User.make! }
    let!(:other_institution) { Institution.make! user: user }
    let!(:other_site)  { Site.make! institution: other_institution }
    let!(:other_device) { Device.make! institution: other_institution, site: other_site }

    before(:each) { sign_in user }
    let(:default_params) { {context: other_institution.uuid} }

    it "should not authorize outsider user" do
      get :show, params: { id: test_result.uuid }
      expect(response).to be_forbidden
    end

    it "should authorize user with access to device" do
      grant owner, user, { :test_result => device }, QUERY_TEST

      get :show, params: { id: test_result.uuid }
      expect(assigns(:test_result)).to eq(test_result)
      expect(response).to be_success
    end

    it "should authorize user with access to site" do
      grant owner, user, { :test_result => site }, QUERY_TEST

      get :show, params: { id: test_result.uuid }
      expect(assigns(:test_result)).to eq(test_result)
      expect(response).to be_success
    end

    it "should authorize user with access to institution" do
      grant owner, user, { :test_result => institution }, QUERY_TEST

      get :show, params: { id: test_result.uuid }
      expect(assigns(:test_result)).to eq(test_result)
      expect(response).to be_success
    end

    context "when original site was moved (ie soft deleted + device changed)" do
      let!(:new_site) { Site.make! institution: institution }

      before(:each) {
        device.site = new_site
        device.save!

        site.destroy!
      }

      it "should authorize user with access to device" do
        grant owner, user, { :test_result => device }, QUERY_TEST

        get :show, params: { id: test_result.uuid }
        expect(assigns(:test_result)).to eq(test_result)
        expect(response).to be_success
      end

      it "should authorize user with access to institution" do
        grant owner, user, { :test_result => institution }, QUERY_TEST

        get :show, params: { id: test_result.uuid }
        expect(assigns(:test_result)).to eq(test_result)
        expect(response).to be_success
      end
    end
  end
end
