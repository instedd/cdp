require "spec_helper"

RSpec.describe SampleTransfersController, type: :controller do
  let!(:my_institution) { Institution.make! }
  let(:my_site) { Site.make!(institution: my_institution) }
  let!(:other_institution) { Institution.make! }
  let!(:current_user) { my_institution.user }
  let(:default_params) { { context: my_institution.uuid } }

  describe "GET #index" do
    before(:each) do
      sign_in current_user
    end

    it "includes transfers from and to my institution (ordered by creation date)" do
      sample_transfers = [
        SampleTransfer.make!(transfer_package: TransferPackage.make!(sender_institution: my_institution), created_at: Time.now - 1.day),
        SampleTransfer.make!(transfer_package: TransferPackage.make!(receiver_institution: my_institution), created_at: Time.now),
      ]
      get :index
      expect(assigns(:sample_transfers).map(&:transfer)).to eq sample_transfers.reverse
    end

    it "excludes transfers not from or to my institution" do
      SampleTransfer.make!
      get :index
      expect(assigns(:sample_transfers)).to be_empty
    end

    describe "filters" do
      let!(:subject) { SampleTransfer.make!(transfer_package: TransferPackage.make!(sender_institution: my_institution), sample: Sample.make!(:filled, batch: Batch.make!, specimen_role: "c")) }
      let!(:other) { SampleTransfer.make!(transfer_package: TransferPackage.make!(receiver_institution: my_institution), sample: Sample.make!(:filled, batch: Batch.make!)) }

      it "by sample id" do
        get :index, params: { sample_id: subject.sample.uuid[0..8] }
        expect(assigns(:sample_transfers).map(&:transfer)).to eq [subject]
      end

      it "by batch_number" do
        get :index, params: { batch_number: subject.sample.batch.batch_number }
        expect(assigns(:sample_transfers).map(&:transfer)).to eq [subject]
      end

      it "by old_batch_number" do
        transfer = SampleTransfer.make!(transfer_package: TransferPackage.make!(sender_institution: my_institution), sample: Sample.make!(:filled, specimen_role: "c", old_batch_number: "12345678"))
        get :index, params: { batch_number: "12345678" }
        expect(assigns(:sample_transfers).map(&:transfer)).to eq [transfer]
      end

      it "by isolate_name" do
        get :index, params: { isolate_name: subject.sample.isolate_name }
        expect(assigns(:sample_transfers).map(&:transfer)).to eq [subject]
      end

      it "by specimen_role" do
        get :index, params: { specimen_role: subject.sample.specimen_role }
        expect(assigns(:sample_transfers).map(&:transfer)).to eq [subject]
      end

      it "combined" do
        get :index, params: { sample_id: subject.sample.uuid[0..8], batch_number: subject.sample.batch.batch_number, isolate_name: subject.sample.isolate_name, specimen_role: subject.sample.specimen_role }
        expect(assigns(:sample_transfers).map(&:transfer)).to eq [subject]
      end
    end
  end

  describe "POST #create" do
    before(:each) do
      sign_in current_user
    end

    it "creates single transfer" do
      sample = Sample.make(:filled, institution: my_institution, site: my_site)

      post :create, params: { institution_id: other_institution.uuid, samples: [sample.uuid] }

      expect(response).to redirect_to(samples_path)
      expect(flash.to_h).to eq({ "notice" => "All samples have been transferred successfully." })

      sample.reload
      expect(sample.site).to be_nil
      expect(sample.institution).to be_nil

      transfer = sample.sample_transfers.take

      expect(transfer.sample).to eq sample
      expect(transfer.sender_institution).to eq my_institution
      expect(transfer.receiver_institution).to eq other_institution
      expect(transfer.transfer_package).to_not be_nil
      expect(transfer).not_to be_confirmed
    end

    it "creates multiple transfers" do
      samples = 3.times.map { Sample.make(:filled, institution: my_institution, site: my_site) }

      post :create, params: { institution_id: other_institution.uuid, samples: samples.map(&:uuid) }

      expect(response).to redirect_to(samples_path)
      expect(flash.to_h).to eq({ "notice" => "All samples have been transferred successfully." })

      samples.each(&:reload)
      expect(samples.map(&:site)).to eq [nil] * 3
      expect(samples.map(&:institution)).to eq [nil] * 3

      transfers = SampleTransfer.all
      expect(transfers.map(&:sender_institution)).to eq [my_institution] * 3
      expect(transfers.map(&:receiver_institution)).to eq [other_institution] * 3
      expect(transfers.map(&:transfer_package_id)).to eq [TransferPackage.take.id] * 3
      expect(transfers.any?(&:confirmed?)).to be false
    end
  end

  describe "PATCH #confirm" do
    before(:each) do
      sign_in current_user
    end

    it "confirms" do
      sample = Sample.make!
      transfer = TransferPackage.sending_to(other_institution, my_institution).add!(sample)

      Timecop.freeze do
        patch :confirm, params: { sample_transfer_id: transfer.id }
        expect(response).to be_success

        transfer.reload
        expect(transfer.confirmed_at).to eq Time.now.change(usec: 0) # account for DB time field granularity
      end

      sample.reload
      expect(sample.institution).to eq my_institution
    end

    it "verifies user is authorized" do
      sample = Sample.make!
      transfer = TransferPackage.sending_to(my_institution, other_institution).add!(sample)

      grant other_institution.user, current_user, other_institution, Policy::Actions::READ_INSTITUTION

      patch :confirm, params: { sample_transfer_id: transfer.id, context: other_institution.uuid }
      expect(response).to be_forbidden

      transfer.reload
      expect(transfer).not_to be_confirmed

      sample.reload
      expect(sample.institution).to be_nil
    end

    it "verifies current context is receiver" do
      sample = Sample.make!
      transfer = TransferPackage.sending_to(my_institution, other_institution).add!(sample)

      expect {
        patch :confirm, params: { sample_transfer_id: transfer.id }
      }.to raise_error(ActiveRecord::RecordNotFound)

      transfer.reload
      expect(transfer).not_to be_confirmed

      sample.reload
      expect(sample.institution).to be_nil
    end

    it "verifies transfer is unconfirmed" do
      sample = Sample.make
      transfer = TransferPackage.sending_to(other_institution, my_institution).add!(sample)
      transfer.confirm_and_apply!
      transfer.confirmed_at = original_confirmed_at = Time.now.change(usec: 0) - 1.hour
      transfer.save!

      patch :confirm, params: { sample_transfer_id: transfer.id }
      expect(response).to be_bad_request

      transfer.reload
      expect(transfer.confirmed_at).to eq original_confirmed_at
    end
  end
end
