include Policy::Actions

def assert_can(user, resource, action, expected_result=nil)
  result = Policy.can? action, resource, user

  expect(result).to eq(true)

  result = Policy.authorize action, resource, user

  expected_result ||= resource

  if expected_result.kind_of?(Resource)
    expect(result).to eq(expected_result)
  else
    expect(result.to_a).to match_array(expected_result.to_a)
  end
end

def assert_cannot(user, resource, action)
  result = Policy.cannot? action, resource, user
  expect(result).to eq(true)
end

def grant(granter, user, resource, action, opts = {})
  [granter, user].compact.each(&:reload)
  policy = Policy.make_unsaved
  policy.definition = policy_definition(resource, action, opts.fetch(:delegable, true), opts.fetch(:except, []))
  policy.granter_id = granter.try(:id)
  policy.user_id = user.id
  policy.allows_implicit = true
  policy.save!
  policy
end

def policy_definition(resource, action, delegable = true, except = [])
  resource = Array(resource).map{|r| r.kind_of?(String) ? r : r.resource_name}
  except = Array(except).map{|r| r.kind_of?(String) ? r : r.resource_name}
  action = Array(action)

  JSON.parse %(
    {
      "statement":  [
        {
          "action": #{action.to_json},
          "resource": #{resource.to_json},
          "except": #{except.to_json},
          "effect": "allow"
        }
      ],
      "delegable": #{delegable}
    }
  )
end
