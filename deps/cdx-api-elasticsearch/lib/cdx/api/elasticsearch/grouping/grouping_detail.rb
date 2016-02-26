class GroupingDetail
  attr_reader :name
  attr_reader :field_definition
  attr_reader :uri_param

  def initialize(name, field_definition, uri_param)
    @name = name
    @field_definition = field_definition
    @uri_param = uri_param
  end

  def nested?
    false
  end

  def self.for(indexed_field, uri_param, values)
    if indexed_field.nested?
      NestedGroupingDetail.create indexed_field, uri_param, values
    else
      grouping = nil

      definition = indexed_field.group_definitions.detect do |definition|
        definition["name"] == uri_param
      end

      if definition
        grouping_def = definition.clone

        if grouping_def["type"] == "range"
          if values
            grouping = RangeGroupingDetail.new indexed_field.scoped_name, indexed_field, uri_param, values
          end
        end

        if grouping_def["type"] == "location"
          grouping = LocationGroupingDetail.new indexed_field.scoped_name, indexed_field, uri_param, values
        end

        if grouping_def["type"] == "duration"
          grouping = DurationGroupingDetail.new indexed_field.scoped_name, indexed_field, uri_param, values
        end

        if !grouping
          if grouping_def["type"] == "date"
            grouping = DateGroupingDetail.new indexed_field.scoped_name, indexed_field, uri_param, grouping_def["interval"]
          else
            grouping = FlatGroupingDetail.new indexed_field.scoped_name, indexed_field, uri_param
          end
        end

        grouping
      end
    end
  end

  def self.process_buckets(aggregations, group_by, entities, entity, doc_count)
    count = aggregations["count"]

    if count
      if group_by.is_a? Array
        head, *rest = group_by
      else
        head, rest = group_by, []
      end

      buckets = head.preprocess_buckets count
      head.process_bucket rest, entities, entity, buckets
    else
      entity["count"] = doc_count
      entities + [entity]
    end
  end

  def preprocess_buckets(count)
    count["buckets"]
  end

  def process_bucket(group_by, entities, entity, buckets)
    buckets.inject entities do |entities, bucket|
      entity = entity.merge yield_bucket(bucket)
      GroupingDetail.process_buckets bucket, group_by, entities, entity, bucket["doc_count"]
    end
  end
end
