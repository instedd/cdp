module AutocompleteFieldHelper
  def autocomplete_field(f, field, institution)
    field_name = field.match(/\[(.*?)\]/)[1]
    react_component "CdxSelectAutocomplete", { name: field, value: f.object.public_send(field_name.to_sym), url: institution_autocomplete_path(institution_id: institution.id, field_name: field_name) }
  end
end
