require 'spec_helper'

describe Manifest do

  context "applying to event" do

    it "should apply to indexed core fields" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "assay_name",
              "source" : {"lookup" : "assay.name"},
              "core" : true
            }]
          }
        },
        '{"assay" : {"name" : "GX4002"}}',
        event: {indexed: {"assay_name" => "GX4002"}, pii: Hash.new, custom: Hash.new}
    end

    it "should apply to pii core field" do
      assert_manifest_application %{
          {
            "patient" : [{
              "target_field" : "patient_name",
              "source" : {"lookup" : "patient.name"},
              "core" : true,
              "pii" : true
            }]
          }
        },
        '{"patient" : {"name" : "John"}}',
        patient: {indexed: Hash.new, pii: {"patient_name" => "John"}, custom: Hash.new}
    end

    it "should apply to custom non-pii non-indexed field" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : false
            }]
          }
        },
        '{"temperature" : 20}',
        event: {indexed: Hash.new, pii: Hash.new, custom: {"temperature" => 20}}
    end

    it "should apply to custom non-pii indexed field" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            }]
          }
        },
        '{"temperature" : 20}',
        event: {indexed: {"custom_fields" => {"temperature" => 20}}, pii: Hash.new, custom: Hash.new}
    end

    it "should apply to custom non-pii indexed field inside results array" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "results[*].temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            }]
          }
        },
        '{"temperature" : 20}',
        event: {indexed: {"results" => [{"custom_fields" => {"temperature" => 20}}]}, pii: Hash.new, custom: Hash.new}
    end

    it "should store fields in sample, event or patient as specified" do
      manifest = Manifest.new(definition: %{
        {
          "metadata": {
            "source" : {"type" : "json"}
          },
          "field_mapping" : {
            "sample" : [
              {
                "target_field" : "sample_id",
                "source" : {"lookup" : "sample_id"},
                "core" : true,
                "indexed" : true
              },
              {
                "target_field" : "sample_type",
                "source" : {"lookup" : "sample_type"},
                "core" : true,
                "indexed" : true
              },
              {
                "target_field" : "culture_days",
                "source" : {"lookup" : "culture_days"},
                "indexed" : true,
                "custom" : true
              },
              {
                "target_field" : "datagram",
                "source" : {"lookup" : "datagram"},
                "custom" : true
              },
              {
                "target_field" : "collected_at",
                "source" : {"lookup" : "collected_at"},
                "pii" : true
              }
            ],
            "patient" : [
              {
                "target_field" : "patient_id",
                "source" : {"lookup" : "patient_id"},
                "pii" : true
              },
              {
                "target_field" : "gender",
                "source" : {"lookup" : "gender"},
                "core" : true,
                "indexed" : true
              },
              {
                "target_field" : "dob",
                "source" : {"lookup" : "dob"},
                "core" : true,
                "pii" : true
              },
              {
                "target_field" : "hiv",
                "source" : {"lookup" : "hiv"},
                "custom" : true,
                "indexed" : true
              },
              {
                "target_field" : "shirt_color",
                "source" : {"lookup" : "shirt_color"},
                "custom" : true
              }
            ],
            "event" : [
              {
                "target_field" : "event_id",
                "source" : {"lookup" : "event_id"},
                "core" : true
              },
              {
                "target_field" : "assay",
                "source" : {"lookup" : "assay"},
                "core" : true,
                "indexed" : true
              },
              {
                "target_field" : "start_time",
                "source" : {"lookup" : "start_time"},
                "core" : true,
                "pii" : true
              },
              {
                "target_field" : "raw_result",
                "source" : {"lookup" : "raw_result"},
                "custom" : true
              },
              {
                "target_field" : "concentration",
                "source" : {"lookup" : "concentration"},
                "custom" : true,
                "indexed" :true
              }
            ]
          }
        }
      })

      result = manifest.apply_to(Oj.dump({
        event_id: "4",                    # event id
        assay: "mtb",                     # test, indexable
        start_time: "2000/1/1 10:00:00",  # test, pii
        concentration: "15%",             # test, indexable, custom
        raw_result: "positivo 15%",       # test, no indexable, custom
        sample_id: "4002",                # sample id
        sample_type: "sputum",            # sample, indexable
        collected_at: "2000/1/1 9:00:00", # sample, pii, non indexable
        culture_days: "10",               # sample, indexable, custom,
        datagram: "010100011100",         # sample, non indexable, custom
        patient_id: "8000",               # patient id
        gender: "male",                   # patient, indexable
        dob: "2000/1/1",                  # patient, pii, non indexable
        hiv: "positive",                  # patient, indexable, custom
        shirt_color: "blue"               # patient, non indexable, custom
      }))

      result.should eq({
        event: {
          indexed: {
            event_id: "4",
            assay: "mtb",
            custom_fields: {
              concentration: "15%"
            }
          },
          custom: {
            raw_result: "positivo 15%"
          },
          pii: {
            start_time: "2000/1/1 10:00:00"
          }
        },
        sample: {
          indexed: {
            sample_id: "4002",
            sample_type: "sputum",
            custom_fields: {
              culture_days: "10"
            }
          },
          custom: {
            datagram: "010100011100"
          },
          pii: {
            collected_at: "2000/1/1 9:00:00"
          }
        },
        patient: {
          indexed: {
            gender: "male",
            custom_fields: {
              hiv: "positive"
            }
          },
          pii: {
            patient_id: "8000",
            dob: "2000/1/1"
          },
          custom: {
            shirt_color: "blue"
          }
        }
      }.recursive_stringify_keys!)
    end

    it "should apply to an array of custom non-pii indexed field inside results array" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "results[*].instant_temperature[*].value",
              "source" : {"lookup" : "tests[*].temperatures[*].value"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            },
            {
              "target_field" : "results[*].instant_temperature[*].sample_time",
              "source" : {"lookup" : "tests[*].temperatures[*].time"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            },
            {
              "target_field" : "results[*].condition",
              "source" : {"lookup" : "tests[*].condition"},
              "core" : true,
              "pii" : false,
              "indexed" : true
            },
            {
              "target_field" : "results[*].result",
              "source" : {"lookup" : "tests[*].result"},
              "core" : true,
              "pii" : false,
              "indexed" : true
            },
            {
              "target_field" : "final_temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            }]
          }
        },
        '{
          "temperature" : 20,
          "tests" : [
            {
              "result" : "positive",
              "condition" : "mtb",
              "temperatures" : [
                { "time": "start", "value": 12},
                { "time" : "end", "value": 23}
              ]
            },
            {
             "result" : "negative",
              "condition" : "rif",
              "temperatures" : [
                {"time" : "start", "value": 22},
                {"time" : "end", "value": 30}
              ]
            }
          ]
        }',
        event: {indexed: {
          "results" => [
            { "condition" => "mtb",
              "result" => "positive",
              "custom_fields" => {"instant_temperature" => [
                {"sample_time" => "start", "value" => 12},
                {"sample_time" => "end", "value" => 23}
              ]}
            },
            { "condition" => "rif",
              "result" => "negative",
              "custom_fields" => {"instant_temperature" => [
                {"sample_time" => "start", "value" => 22},
                {"sample_time" => "end", "value" => 30}
              ]}
            }
          ],
          "custom_fields" => {"final_temperature" => 20}
        }, pii: Hash.new, custom: Hash.new}
    end

    it "should apply to custom pii field" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : true,
              "indexed" : false
            }]
          }
        },
        '{"temperature" : 20}',
        event: {indexed: Hash.new, pii: {"temperature" => 20}, custom: Hash.new}
    end

    it "doesn't raise on valid value in options" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "level",
              "source" : {"lookup" : "level"},
              "core" : true,
              "pii" : false,
              "indexed" : true,
              "options" : ["low", "medium", "high"]
            }]
          }
        },
        '{"level" : "high"}',
        event: {indexed: {"level" => "high"}, pii: Hash.new, custom: Hash.new}
    end

    it "should raise on invalid value in options" do
      assert_raises_manifest_data_validation %{
          {
            "event" : [{
              "target_field" : "level",
              "type" : "enum",
              "source" : {"lookup" : "level"},
              "core" : false,
              "pii" : false,
              "indexed" : true,
              "options" : ["low", "medium", "high"]
            }]
          }
        },
        '{"level" : "John Doe"}',
        "'John Doe' is not a valid value for 'level' (valid options are: low, medium, high)"
    end

    it "doesn't raise on valid value in range" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true,
              "valid_values" : {
                "range" : {
                  "min" : 30,
                  "max" : 30
                }
              }
            }]
          }
        },
        '{"temperature" : 30}',
        event: {indexed: {"custom_fields" => {"temperature" => 30}}, pii: Hash.new, custom: Hash.new}
    end

    it "should raise on invalid value in range (lesser)" do
      assert_raises_manifest_data_validation %{
          {
            "event" : [{
              "target_field" : "temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true,
              "valid_values" : {
                "range" : {
                  "min" : 30,
                  "max" : 31
                }
              }
            }]
          }
        },
        '{"temperature" : 29.9}',
        "'29.9' is not a valid value for 'temperature' (valid values must be between 30 and 31)"
    end

    it "should raise on invalid value in range (greater)" do
      assert_raises_manifest_data_validation %{
          {
            "event" : [{
              "target_field" : "temperature",
              "source" : {"lookup" : "temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true,
              "valid_values" : {
                "range" : {
                  "min" : 30,
                  "max" : 31
                }
              }
            }]
          }
        },
        '{"temperature" : 31.1}',
        "'31.1' is not a valid value for 'temperature' (valid values must be between 30 and 31)"
    end

    it "doesn't raise on valid value in date iso" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "sample_date",
              "source" : {"lookup" : "sample_date"},
              "core" : true,
              "pii" : false,
              "indexed" : true,
              "valid_values" : {
                "date" : "iso"
              }
            }]
          }
        },
        '{"sample_date" : "2014-05-14T15:22:11+0000"}',
        event: {indexed: {"sample_date" => "2014-05-14T15:22:11+0000"}, pii: Hash.new, custom: Hash.new}
    end

    it "should raise on invalid value in date iso" do
      assert_raises_manifest_data_validation %{
          {
            "event" : [{
              "target_field" : "sample_date",
              "source" : {"lookup" : "sample_date"},
              "core" : true,
              "pii" : false,
              "indexed" : true,
              "valid_values" : {
                "date" : "iso"
              }
            }]
          }
        },
        '{"sample_date" : "John Doe"}',
        "'John Doe' is not a valid value for 'sample_date' (valid value must be an iso date)"
    end

    it "applies first value mapping" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "condition",
              "source" : {
                "map" : [
                  {"lookup" : "condition"},
                  [
                    { "match" : "*MTB*", "output" : "MTB"},
                    { "match" : "*FLU*", "output" : "H1N1"},
                    { "match" : "*FLUA*", "output" : "A1N1"}
                  ]
                ]
              },
              "core" : true,
              "pii" : false,
              "indexed" : true
            }]
          }
        },
        '{"condition" : "PATIENT HAS MTB CONDITION"}',
        event: {indexed: {"condition" => "MTB"}, pii: Hash.new, custom: Hash.new}
    end

    it "applies second value mapping" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "condition",
              "source" : {
                "map" : [
                  {"lookup" : "condition"},
                  [
                    { "match" : "*MTB*", "output" : "MTB"},
                    { "match" : "*FLU*", "output" : "H1N1"},
                    { "match" : "*FLUA*", "output" : "A1N1"}
                  ]
                ]
              },
              "core" : true,
              "pii" : false,
              "indexed" : true
            }]
          }
        },
        '{"condition" : "PATIENT HAS FLU CONDITION"}',
        event: {indexed: {"condition" => "H1N1"}, pii: Hash.new, custom: Hash.new}
    end

    it "should raise on mapping not found" do
      assert_raises_manifest_data_validation %{
          {
            "event" : [{
              "target_field" : "condition",
              "source" : {
                "map" : [
                  {"lookup" : "condition"},
                  [
                    { "match" : "*MTB*", "output" : "MTB"},
                    { "match" : "*FLU*", "output" : "H1N1"},
                    { "match" : "*FLUA*", "output" : "A1N1"}
                  ]
                ]
              },
              "core" : false,
              "pii" : false,
              "indexed" : true
            }]
          }
        },
        '{"condition" : "PATIENT IS OK"}',
        "'PATIENT IS OK' is not a valid value for 'condition' (valid value must be in one of these forms: *MTB*, *FLU*, *FLUA*)"
    end

    it "should apply to multiple indexed field" do
      assert_manifest_application %{
          {
            "event" : [{
              "target_field" : "list[*].temperature",
              "source" : {"lookup" : "temperature_list[*].temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            }]
          }
        },
        '{"temperature_list" : [{"temperature" : 20}, {"temperature" : 10}]}',
        event: {indexed: {"custom_fields" => {"list" => [{"temperature" => 20}, {"temperature" => 10}]}}, pii: Hash.new, custom: Hash.new}
    end

    it "should map to multiple indexed fields to the same list" do
      assert_manifest_application %{{
          "event" : [
            {
              "target_field" : "collection[*].temperature",
              "source" : {"lookup" : "some_list[*].temperature"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            },
            {
              "target_field" : "collection[*].foo",
              "source" : {"lookup" : "some_list[*].bar"},
              "core" : false,
              "pii" : false,
              "indexed" : true
            }
          ]}
        },
        '{
          "some_list" : [
            {
              "temperature" : 20,
              "bar" : 12
            },
            {
              "temperature" : 10,
              "bar" : 2
            }
          ]
        }',
        event: {indexed: {"custom_fields" => {"collection" => [
          {
            "temperature" => 20,
            "foo" => 12
          },
          {
            "temperature" => 10,
            "foo" => 2
          }]}}, pii: Hash.new, custom: Hash.new}
    end

    it "should map to multiple indexed fields to the same list accross multiple collections" do
      assert_manifest_application %{{
          "event" : [
            {
              "target_field" : "collection[*].temperature",
              "source" : {"lookup" : "temperature_list[*].temperature"},
              "core" : true,
              "pii" : false,
              "indexed" : true
            },
            {
              "target_field" : "collection[*].foo",
              "source" : {"lookup" : "other_list[*].bar"},
              "core" : true,
              "pii" : false,
              "indexed" : true
            }
          ]
        }},
        '{
          "temperature_list" : [{"temperature" : 20}, {"temperature" : 10}],
          "other_list" : [{"bar" : 10}, {"bar" : 30}, {"bar" : 40}]
        }',
        event: {indexed: {"collection" => [
          {
            "temperature" => 20,
            "foo" => 10
          },
          {
            "temperature" => 10,
            "foo" => 30
          },
          {
            "foo" => 40
          }]}, pii: Hash.new, custom: Hash.new}
    end

  end

end
