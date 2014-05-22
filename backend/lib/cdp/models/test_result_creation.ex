defmodule TestResultCreation do
  use Timex
  import Tirexs.Bulk

  def update_pii(result_uuid, data, date \\ :calendar.universal_time()) do
    date = Ecto.DateTime.from_erl(date)

    sensitive_data = Enum.map TestResult.sensitive_fields, fn field_name ->
      {field_name, data[atom_to_binary(field_name)]}
    end

    test_result = TestResult.find_by_uuid_in_postgres(result_uuid)
    test_result = test_result.sensitive_data sensitive_data
    test_result = test_result.updated_at date
    test_result = TestResult.encrypt(test_result)

    Repo.update(test_result)
  end

  def create(device_key, raw_data, date \\ :calendar.universal_time()) do
    create(Device.find_by_key(device_key), raw_data, JSEX.decode!(raw_data), date, :erlang.iolist_to_binary(:uuid.to_string(:uuid.uuid1())))
  end

  def create({device, [], laboratories}, raw_data, data, date, uuid) do
    # TODO: when no manifest is found we should use a default mapping

    sensitive_data = Enum.map TestResult.sensitive_fields, fn field_name ->
      {field_name, data[atom_to_binary(field_name)]}
    end
    create_in_db(device, sensitive_data, [], raw_data, date, uuid)

    data = Dict.drop(data, (Enum.map TestResult.sensitive_fields, &atom_to_binary(&1)))
    create_in_elasticsearch(device, laboratories, data, date, uuid)
  end

  def create({device, [manifest], laboratories}, raw_data, data, date, uuid) do
    data = Manifest.apply(JSEX.decode!(manifest.definition), data)
    create_in_db(device, data[:pii], data[:custom], raw_data, date, uuid)
    create_in_elasticsearch(device, laboratories, data[:indexed], date, uuid)
  end

  def create({device, [manifest| manifests], laboratories}, raw_data, data, date, uuid) do
    manifest = Enum.reduce manifests, manifest, fn(current_manifest, last_manifest) ->
      if last_manifest.version < current_manifest.version do
        current_manifest
      else
        last_manifest
      end
    end
    create({device, [manifest], laboratories}, raw_data, data, date, uuid)
  end

  defp create_in_db(device, sensitive_data, custom_data, raw_data, date, uuid) do
    date = Ecto.DateTime.from_erl(date)

    test_result = TestResult.new [
      device_id: device.id,
      raw_data: raw_data,
      uuid: uuid,
      sensitive_data: sensitive_data,
      custom_fields: JSEX.encode!(custom_data),
      created_at: date,
      updated_at: date,
    ]

    test_result = TestResult.encrypt(test_result)
    Repo.insert(test_result)
  end

  defp create_in_elasticsearch(device, [], data, date, uuid) do
    create_in_elasticsearch(device, nil, [], nil, date, data, uuid)
  end

  defp create_in_elasticsearch(device, [laboratory], data, date, uuid) do
    laboratory_id = laboratory.id
    location_id = laboratory.location_id
    parent_locations = Location.with_parents Repo.get(Location, laboratory.location_id)
    create_in_elasticsearch(device, laboratory_id, parent_locations, location_id, date, data, uuid)
  end

  defp create_in_elasticsearch(device, laboratories, data, date, uuid) do
    locations = (Enum.map laboratories, fn laboratory -> Repo.get Location, laboratory.location_id end)
    root_location = Location.common_root(locations)
    parent_locations = Location.with_parents root_location
    if root_location do
      location_id = root_location.id
    end
    create_in_elasticsearch(device, nil, parent_locations, location_id, date, data, uuid)
  end

  defp create_in_elasticsearch(device, laboratory_id, parent_locations, location_id, date, data, uuid) do
    institution_id = device.institution_id
    data = Dict.put data, :type, "test_result"
    data = Dict.put data, :created_at, (DateFormat.format!(Date.from(date), "{ISO}"))
    data = Dict.put data, :device_uuid, device.secret_key
    data = Dict.put data, :location_id, location_id
    data = Dict.put data, :parent_locations, parent_locations
    data = Dict.put data, :laboratory_id, laboratory_id
    data = Dict.put data, :institution_id, institution_id
    data = Dict.put data, :uuid, uuid

    settings = Tirexs.ElasticSearch.Config.new()
    Tirexs.Bulk.store [index: Institution.elasticsearch_index_name(institution_id), refresh: true], settings do
      create data
    end
  end
end
