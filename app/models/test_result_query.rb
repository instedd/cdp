class TestResultQuery < Cdx::Api::Elasticsearch::Query
  include Policy::Actions

  class << self
    private :new
  end

  def self.for params, user
    policies = ComputedPolicy.applicable_policies(QUERY_TEST, TestResult, user).includes(:exceptions)
    if policies.any?
      new params, policies
    else
      Cdx::Api::Elasticsearch::NullQuery.new(params, Cdx::Fields.test)
    end
  end

  def self.find_by_elasticsearch_id(id)
    doc = Cdx::Api.client.get index: Cdx::Api.index_name, type: 'test', id: id
    add_names_to([doc["_source"]]).first
  end

  def initialize(params, policies)
    super(params, Cdx::Fields.test)
    @policies = policies
  end

  def process_conditions(*args)
    query = super

    preloaded_uuids = preload_uuids_for(@policies)

    policies_conditions = @policies.map do |policy|
      positive  = super(conditions_for(policy, preloaded_uuids))
      negatives = policy.exceptions.map { |exception| super(conditions_for(exception, preloaded_uuids)) }

      if negatives.empty?
        and_conditions(positive)
      else
        { bool: { must: positive, must_not: negatives } }
      end
    end

    query << or_conditions(policies_conditions)
    query
  end

  def execute
    result = super
    TestResultQuery.add_names_to result["tests"]
    result
  end

  def csv_builder
    if grouped_by.empty?
      CSVBuilder.new execute["tests"]
    else
      CSVBuilder.new execute["tests"], column_names: grouped_by.concat(["count"])
    end
  end

  protected

  def not_conditions conditions
    return conditions.first if conditions.size == 1
    {bool: {must_not: conditions}}
  end

  private

  def conditions_for(computed_policy, preloaded_uuids)
    Hash[computed_policy.conditions.map do |field, value|
      if field == :site
        # In the case of a site the resource_id is a prefix of all uuids
        ["#{field}.path", value.split(".").last] unless value.nil?
      else
        ["#{field}.uuid", preloaded_uuids[field][value.to_i]] unless value.nil?
      end
    end.compact]
  end

  def preload_uuids_for(policies)
    resource_ids = Hash.new { |h,k| h[k] = Set.new }

    (policies + policies.map(&:exceptions).flatten).each do |policy|
      policy.conditions.each do |field, value|
        resource_ids[field] << value
      end
    end

    Hash[resource_ids.map do |field, ids|
      if field == :site
        # In the case of a site the resource_id is a prefix of all uuids
        [field, ids]
      else
        [field, Hash[field.to_s.classify.constantize.where(id: ids.to_a).pluck(:id, :uuid)]]
      end
    end]
  end

  def self.add_names_to tests
    institutions = indexed_model tests, Institution, ["institution", "uuid"]
    sites = indexed_model tests, Site, ["site", "uuid"]
    devices = indexed_model tests, Device, ["device", "uuid"]

    tests.each do |test|
      test["institution"]["name"] = institutions[test["institution"]["uuid"]].try(:name) if test["institution"]
      test["device"]["name"] = devices[test["device"]["uuid"]].try(:name) if test["device"]
      test["site"]["name"] = sites[test["site"]["uuid"]].try(:name) if test["site"]
    end
  end

  def self.indexed_model(tests, model, es_field)
    ids = tests.map { |test| es_field.inject(test) { |obj, field| obj[field] } rescue nil }.uniq
    model.where("uuid" => ids).index_by { |model| model["uuid"] }
  end
end
