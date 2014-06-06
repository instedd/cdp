class Policy < ActiveRecord::Base
  belongs_to :user
  belongs_to :granter, class_name: 'User', foreign_key: 'granter_id'

  validates_presence_of :name, :granter, :user, :definition
  validate :validate_definition
  validate :validate_owner_permissions

  serialize :definition, JSON

  before_save :set_delegable_from_definition

  module Actions
    PREFIX = "cdpx"

    CREATE_INSTITUTION = "#{PREFIX}:createInstitution"
    READ_INSTITUTION = "#{PREFIX}:readInstitution"
    UPDATE_INSTITUTION = "#{PREFIX}:updateInstitution"
    DELETE_INSTITUTION = "#{PREFIX}:deleteInstitution"

    CREATE_INSTITUTION_LABORATORY = "#{PREFIX}:createInstitutionLaboratory"
    READ_LABORATORY = "#{PREFIX}:readLaboratory"
    UPDATE_LABORATORY = "#{PREFIX}:updateLaboratory"
    DELETE_LABORATORY = "#{PREFIX}:deleteLaboratory"

    REGISTER_INSTITUTION_DEVICE = "#{PREFIX}:registerInstitutionDevice"
    READ_DEVICE = "#{PREFIX}:readDevice"
    UPDATE_DEVICE = "#{PREFIX}:updateDevice"
    DELETE_DEVICE = "#{PREFIX}:deleteDevice"
    ASSIGN_DEVICE_LABORATORY = "#{PREFIX}:assignDeviceLaboratory"
    REGENERATE_DEVICE_KEY = "#{PREFIX}:regenerateDeviceKey"
  end

  ACTIONS = [
    Actions::READ_INSTITUTION, Actions::UPDATE_INSTITUTION, Actions::DELETE_INSTITUTION,
    Actions::CREATE_INSTITUTION_LABORATORY, Actions::READ_LABORATORY, Actions::UPDATE_LABORATORY, Actions::DELETE_LABORATORY,
    Actions::REGISTER_INSTITUTION_DEVICE, Actions::READ_DEVICE, Actions::UPDATE_DEVICE, Actions::DELETE_DEVICE, Actions::ASSIGN_DEVICE_LABORATORY, Actions::REGENERATE_DEVICE_KEY,
  ]

  def self.delegable
    where(delegable: true)
  end

  def self.superadmin
    predefined_policy "superadmin"
  end

  def self.implicit
    predefined_policy "implicit"
  end

  def self.check_all(action, resource, policies, user)
    check_all_recursive action, resource, policies, user
  end

  def self.check_all_recursive(action, resource, policies, user, users_so_far = Set.new)
    # If the resource we are checking is an array, it is a group of instances that
    # we are checking. The simplest (but slowest) way is to check if we can perform
    # the action on each of this instances, and then keep the last one as the result.
    if resource.is_a?(Array)
      result = nil
      resource.each do |sub_resource|
        result = check_all_recursive action, sub_resource, policies, user
        return nil unless result
      end

      return result
    end

    allowed = []
    denied = []

    policies.each do |policy|
      policy.definition["statement"].each do |statement|
        match = policy.check(statement, action, resource, user, users_so_far)
        if match
          if statement["effect"] == "allow"
            allowed << match
          else
            denied << match
          end
        end
      end
    end

    classes = denied.select { |klass| klass.is_a?(Class) }
    allowed -= classes
    denied -= classes

    [allowed, denied].each do |resources|
      resources.map! do |resource|
        resource.is_a?(Class) ? resource.all : resource
      end
      resources.flatten!
      resources.uniq!
    end

    result = allowed - denied
    result.presence
  end

  def check(statement, action, resource, user, users_so_far)
    return nil unless action_matches?(action, statement["action"])

    resource = apply_resource_filters(resource, statement["resource"])
    return nil unless resource

    if (condition = statement["condition"])
      resource = apply_condition(resource, condition, user)
      return nil unless resource
    end

    # Check that the granter's policies allow the action on the resource,
    # but only if the user is not the same as the granter (like implicit and superadmin policies)
    if !implicit? && !users_so_far.include?(granter)
      users_so_far.add granter
      granter_result = Policy.check_all_recursive action, resource, granter.policies.delegable, granter, users_so_far
      users_so_far.delete granter

      return nil unless granter_result

      resource = granter_result
    end

    resource
  end

  def implicit?
    self.granter_id == nil
  end

  def self_granted?
    self.user_id == self.granter_id
  end

  private

  def validate_owner_permissions
    return errors.add :owner, "permission can't be self granted" if self_granted?
    return errors.add :owner, "permission granter can't be nil" if implicit?

    resources = definition["statement"].map do |statement|
      Array(statement["action"]).map do |action|
        Array(statement["resource"]).map do |resource_matcher|
          resources = Array(Resource.find(resource_matcher))
          resources.map do |resource|
            Policy.check_all(action, resource, granter.policies.delegable, granter)
          end
        end
      end
    end.flatten.compact

    if resources.empty?
      return errors.add :owner, "can't delegate permission"
    end
    true
  end

  def validate_definition
    unless definition["statement"]
      return errors.add :definition, "is missing a statement"
    end

    definition["statement"].each do |statement|
      effect = statement["effect"]
      if effect
        if effect != "allow" && effect != "deny"
          return errors.add :definition, "has an invalid effect: `#{effect}`"
        end
      else
        return errors.add :definition, "is missing efect in statement"
      end

      actions = statement["action"]
      if actions
        actions = Array(actions)
        actions.each do |action|
          next if action == "*"

          unless ACTIONS.include?(action)
            return errors.add :definition, "has an unknown action: `#{action}`"
          end
        end
      else
        return errors.add :definition, "is missing action in statemenet"
      end

      resources = statement["resource"]
      if resources
        resources.each do |resource|
          found_resource = Resource.all.any? do |klass|
            klass.filter_by_resource(resource)
          end
          unless found_resource
            return errors.add :definition, "has an unknown resource: `#{resource}`"
          end
        end
        # TODO: validate resources
      else
        return errors.add :definition, "is missing resource in statement"
      end
    end

    delegable = definition["delegable"]
    if !delegable.nil?
      if delegable != true && delegable != false
        return errors.add :definition, "has an invalid delegable value: `#{delegable}`"
      end
    else
      return errors.add :definition, "is missing delegable attribute"
    end
  end

  def set_delegable_from_definition
    self.delegable = definition["delegable"]
    true
  end

  def action_matches?(action, action_filters)
    action_filters = Array(action_filters)
    action_filters.any? do |action_filter|
      action_filter == "*" || action_filter == action
    end
  end

  def apply_resource_filters(resource, resource_filters)
    resource_filters = Array(resource_filters)
    resource_filters.each do |resource_filter|
      if resource_filter == "*"
        return resource
      end

      new_resource = resource.filter_by_resource(resource_filter)
      if new_resource
        return new_resource
      end
    end

    nil
  end

  def apply_condition(resource, condition, user)
    condition.each do |key, value|
      case key
      when "is_owner"
        resource = resource.filter_by_owner(user)
      end
    end

    resource
  end

  def self.predefined_policy(name)
    policy = Policy.new
    policy.name = name
    policy.definition = JSON.load File.read("#{Rails.root}/app/policies/#{name}.json")
    policy.delegable = policy.definition["delegable"]
    policy
  end
end
