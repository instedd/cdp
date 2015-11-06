require 'spec_helper'

describe Cdx do
  it "should provide a collection of fields" do
    expect(Cdx::Fields.test_result.core_fields.map(&:scoped_name).sort).to eq([
      "test.site_user",
      "device.model",
      "device.name",
      "device.serial_number",
      "device.uuid",
      "institution.uuid",
      "institution.name",
      "site.uuid",
      "site.name",
      "site.path",
      "location.admin_levels",
      "location.id",
      "location.lat",
      "location.lng",
      "location.parents",
      "patient.gender",
      "patient.id",
      "patient.name",
      "patient.dob",
      "sample.collection_date",
      "sample.id",
      "sample.type",
      "sample.uuid",
      "test.assays.result",
      "test.assays.name",
      "test.assays.condition",
      "test.assays.quantitative_result",
      "test.end_time",
      "test.error_code",
      "test.error_description",
      "test.name",
      "test.reported_time",
      "test.start_time",
      "test.status",
      "test.type",
      "test.updated_time",
      "test.uuid",
      "test.id",
      "encounter.id",
      "encounter.uuid",
      "encounter.patient_age",
      "encounter.start_time",
      "encounter.end_time",
    ].sort)
  end
end
