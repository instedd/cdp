class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :timeoutable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable,
         :validatable, :confirmable, :omniauthable, :timeoutable,
         :lockable, :password_expirable, :password_archivable

  has_many :identities, dependent: :destroy
  has_many :institutions
  has_many :sites, through: :institutions
  has_many :devices, through: :institutions
  has_many :filters
  has_many :subscribers
  has_many :policies
  has_many :granted_policies, class_name: "Policy", foreign_key: "granter_id"
  has_many :computed_policies

  after_create :update_computed_policies

  def timeout_in
    Settings.web_session_timeout.try{ |timeout| timeout.to_i.seconds }
  end

  def create(model)
    if model.respond_to?(:user=)
      model.user = self
    end
    model.save ? model : nil
  end

  def implicit_policies
    self.institutions.pluck(:id, :kind).map do |institution_id, kind|
      Policy.owner(self, institution_id, kind)
    end + [Policy.implicit(self)].compact
  end

  def update_computed_policies
    ComputedPolicy.update_user(self)
  end

  def grant_superadmin_policy
    grant_predefined_policy("superadmin")
  end

  def grant_predefined_policy(name, args={})
    predefined = Policy.predefined_policy(name, self, args)
    predefined.granter = nil
    predefined.user = self
    predefined.save!
  end

end
