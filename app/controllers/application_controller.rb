class ApplicationController < ActionController::Base
  include ApplicationHelper
  include Policy::Actions

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  skip_before_filter :verify_authenticity_token, if: :json_request?

  before_action :authenticate_user!
  before_action :check_no_institution!
  before_action :load_js_global_settings
  before_action :ensure_context

  decent_configuration do
    strategy DecentExposure::StrongParametersStrategy
  end

  def render_json(object, params={})
    render params.merge(text: object.to_json_oj, content_type: 'text/json')
  end

  def self.set_institution_tab(key)
    before_filter do
      send :set_institution_tab, key
    end
  end

  def set_institution_tab(key)
    @institution_tab = key
  end

  def load_js_global_settings
    gon.location_service_url = Settings.location_service_url
    gon.location_service_set = Settings.location_service_set
  end

  def authorize_resource(resource, action)
    if Policy.can?(action, resource, current_user)
      Policy.authorize(action, resource, current_user)
    else
      head :forbidden
      nil
    end
  end

  def check_no_institution!
    return if current_user && current_user.need_change_password?
    if current_user && current_user.institutions.empty? && current_user.policies.empty?
      if has_access?(Institution, CREATE_INSTITUTION)
        redirect_to new_institution_path
      else
        redirect_to pending_approval_institutions_path
      end
    end
  end

  # filters/authorize navigation_context institutions by action. Assign calls resource.institution= if action is allowed
  def prepare_for_institution_and_authorize(resource, action)
    if authorize_resource(@navigation_context.institution, action).blank?
      head :forbidden
      nil
    else
      resource.institution = @navigation_context.institution
    end
  end

  def default_url_options(options={})
    if params[:context].present?
      return {:context => params[:context]}
    end

    {}
  end

  def ensure_context
    return if request.xhr?

    if current_user.nil?
      return
    end

    if params[:context].blank?
      # if there is no context information force it to be explicit
      # this will trigger a redirect ?context=<institution_or_site_uuid>

      # grab last context stored in user
      default_context = current_user.last_navigation_context

      # if user has no longer access, reset it to anything that make sense
      if default_context.nil? || !NavigationContext.new(current_user, default_context).can_read?
        some_institution_uuid = check_access(Institution, READ_INSTITUTION).first.try(:uuid)
        current_user.update_attribute(:last_navigation_context, some_institution_uuid)
        default_context = some_institution_uuid
      end

      if default_context
        redirect_to url_for(params.merge({context: default_context}))
      end
    else
      # if there is an explicit context try to use it.  
      @navigation_context = NavigationContext.new(current_user, params[:context])

      if @navigation_context.can_read?
        current_user.update_attribute(:last_navigation_context, params[:context])
      else
        # if the user has no longer access to this context, reset it
        redirect_to url_for(params.merge({context: nil}))
      end
    end
  end

  protected

  def json_request?
    request.format.json?
  end
end
