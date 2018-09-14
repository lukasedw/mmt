# :nodoc:
class ApplicationController < ActionController::Base
  include Pundit

  # Prevent CSRF attacks by raising an exception.
  protect_from_forgery with: :exception

  before_action :ensure_user_is_logged_in
  before_action :setup_query
  before_action :refresh_urs_if_needed, except: [:logout, :refresh_token] # URS login
  before_action :refresh_launchpad_if_needed, except: [:logout] # Launchpad login
  before_action :provider_set?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  # Seconds ahead of the token expiration that the server should
  # attempt to refresh the token
  SERVER_EXPIRATION_OFFSET_S = 60
  # For testing, token expires after 10 seconds
  # SERVER_EXPIRATION_OFFSET_S = 3590

  # session keys we use for Launchpad login
  LAUNCHPAD_SESSION_KEYS = %i[
    auid
    expires_in
    launchpad_cookie
    logged_in_at
    original_logged_in_at
    urs_uid
  ].freeze

  # session keys we use for URS login
  URS_SESSION_KEYS = %i[
    access_token
    endpoint
    expires_in
    logged_in_at
    refresh_token
  ].freeze

  def urs_login_required?
    ENV['urs_login_required'] != 'false'
  end
  helper_method :urs_login_required?

  def invite_users_enabled?
    Rails.configuration.invite_users_enabled
  end
  helper_method :invite_users_enabled?

  def launchpad_login_required?
    ENV['launchpad_login_required'] == 'true'
  end
  helper_method :launchpad_login_required?

  def hide_launchpad_button?
    ENV['hide_launchpad_button'] != 'false'
  end
  helper_method :hide_launchpad_button?

  def cmr_client
    @cmr_client ||= Cmr::Client.client_for_environment(Rails.configuration.cmr_env, Rails.configuration.services)
  end
  helper_method :cmr_client

  def echo_client
    @echo_client ||= Echo::Client.client_for_environment(Rails.configuration.echo_env, Rails.configuration.services)
  end
  helper_method :echo_client

  def setup_query
    @query ||= {}
    providers_response = cmr_client.get_providers
    @provider_ids ||= if providers_response.success?
                        providers_response.body.map { |provider| [provider['short-name'], provider['provider-id']] }.sort
                      else
                        Rails.logger.error("Error retrieving providers in `setup_query`: #{providers_response.inspect}")
                        []
                      end
  end

  def current_user
    @current_user ||= User.from_urs_uid(authenticated_urs_uid)
  end
  helper_method :current_user

  # By default Pundit calls the current_user method during authorization
  # but for our calls to the CMR ACL we need user information as well as
  # the users valid token. This provides our policies with the ability to
  # retrieve the authenticated user and also their token
  def pundit_user
    UserContext.new(current_user, token)
  end

  def current_provider?(provider)
    current_user.provider_id == provider
  end
  helper_method :current_provider?

  def available_provider?(provider)
    (current_user.available_providers || []).include?(provider)
  end
  helper_method :available_provider?

  def provider_set?
    if logged_in? && current_user.provider_id.nil?
      redirect_to provider_context_path
    end
  end

  def store_profile(profile = {})
    # store URS profile information in the session

    # URS login && Launchpad login
    uid = session[:endpoint].split('/').last if session[:endpoint]

    session[:name] = profile['first_name'].nil? ? uid : "#{profile['first_name']} #{profile['last_name']}"
    session[:urs_uid] = profile['uid'] || uid
    session[:email_address] = profile['email_address']

    # Echo Id is not being used, so this should be removed as part of MMT-1446
    # Also, CMR can't get a user's Echo Id from their launchpad token
    # Store ECHO ID
    # if current_user.echo_id.nil?
    #   puts "echo id is nil"
    #   response = cmr_client.get_current_user(token)
    #   if response.success?
    #     Rails.logger.info "echo user response in store_profile: #{response.inspect}"
    #     echo_user = response.body
    #
    #     current_user.update(echo_id: echo_user.fetch('user', {}).fetch('id'))
    #   end
    # end
    #
    # # With no echo_id we cannot request providers for the user, no sense in continuing
    # return if current_user.echo_id.nil?
  end

  def store_oauth_token(oauth_response)
    # URS login
    session[:access_token] = oauth_response['access_token']
    session[:endpoint] = oauth_response['endpoint']
    session[:expires_in] = oauth_response['expires_in']
    session[:logged_in_at] = Time.now.to_i
    session[:refresh_token] = oauth_response['refresh_token']
  end

  def logged_in?
    if launchpad_login_required? && session[:login_method] == 'launchpad'
      is_user_logged_in = LAUNCHPAD_SESSION_KEYS.all? { |session_key| session[session_key].present? }
    elsif urs_login_required? && session[:login_method] == 'urs'
      is_user_logged_in = URS_SESSION_KEYS.all? { |session_key| session[session_key].present? }
    end

    is_user_logged_in
  end
  helper_method :logged_in?

  def ensure_user_is_logged_in
    ensure_at_least_one_login_method || return

    session[:return_to] = request.fullpath

    Rails.logger.info("#{session[:login_method] == 'launchpad' ? 'Launchpad' : 'URS'} token: #{token}") if Rails.env.development?

    return true if logged_in?

    # user is not logged in, clear related session data
    clear_session_and_token_data

    if both_login_methods_on?
      # user needs to choose which login method they want to use
      redirect_to root_url
    else
      redirect_to login_path
    end
  end

  def logged_in_at
    session[:logged_in_at] || 0
  end

  def expires_in
    (logged_in_at + session[:expires_in]) - Time.now.to_i
  end

  def server_session_expires_in
    logged_in? ? (expires_in - SERVER_EXPIRATION_OFFSET_S).to_i : 0
  end

  def refresh_urs_if_needed
    # URS login
    if urs_login_required? && session[:login_method] == 'urs'
      refresh_urs_token if logged_in? && server_session_expires_in < 0
    end
  end

  def refresh_urs_token
    # URS login
    response = cmr_client.refresh_token(session[:refresh_token])
    return nil unless response.success?

    json = response.body
    store_oauth_token(json)

    if json.nil? && !request.xhr?
      session[:last_point] = request.fullpath

      redirect_to cmr_client.urs_login_path
    end

    json
  end

  def refresh_launchpad_if_needed
    # Launchpad login
    if launchpad_login_required? && session[:login_method] == 'launchpad'
      if logged_in? && server_session_expires_in < 0
        response = refresh_launchpad

        redirect_to sso_url unless response[:success]
      end
    end
  end

  def refresh_launchpad
    return { error: 'session older than 8 hours' } if Time.now.to_i - session[:original_logged_in_at] > 28_800

    # If we are in development and the user is not on the VPN, this call will
    # not be able to connect to the keep_alive endpoint, and will timeout or
    # raise an error. So we should fake a successful response from the keep
    # alive endpoint. If this method needs to behave as if in any other
    # environment for development purposes, comment out this entire if and
    # begin rescue statement
    if Rails.env.development?
      begin
        Timeout::timeout(30) { response = cmr_client.keep_alive(token) }
      rescue => e
        Rails.logger.info "keeping keep_alive alive in development. response: #{response.body}; error: #{e.inspect}"

        session[:expires_in] = 900
        session[:logged_in_at] = Time.now.to_i

        return { success: Time.now.to_s }
      end
    end

    response = cmr_client.keep_alive(token)

    Rails.logger.info "launchpad integration keep alive endpoint response: #{response.inspect}" if Rails.env.development?

    if response.success?
      session[:launchpad_cookie] = response.headers.fetch('set-cookie', '').split("#{launchpad_cookie_name}=").last.split(';').first

      session[:expires_in] = 900
      session[:logged_in_at] = Time.now.to_i

      { success: Time.now.to_s }
    else
      { error: 'could not keep alive', time: Time.now.to_s }
    end
  end

  def token
    if session[:login_method] == 'launchpad'
      session[:launchpad_cookie]
    elsif session[:login_method] == 'urs'
      session[:access_token]
    end
  end
  helper_method :token

  def token_with_client_id
    if Rails.env.development? && params[:controller] == 'collections' && params[:action] == 'show'
      # in development, only for download_xml links, we need to use the tokens created on local cmr setup
      'ABC-2'
    else
      services = Rails.configuration.services
      config = services['earthdata'][Rails.configuration.cmr_env]
      client_id = services['urs'][Rails.env.to_s][config['urs_root']]

      "#{token}:#{client_id}"
    end
  end
  helper_method :token_with_client_id

  def echo_provider_token
    set_provider_context_token if session[:echo_provider_token].nil?

    session[:echo_provider_token]
  end
  helper_method :echo_provider_token

  def redirect_after_login
    return_to = session[:return_to]
    session[:return_to] = nil

    last_point = session[:last_point]
    session[:last_point] = nil

    redirect_to return_to || last_point || manage_collections_path
  end

  private

  def groups_enabled?
    redirect_to manage_collections_path unless Rails.configuration.groups_enabled
  end

  def bulk_updates_enabled?
    redirect_to manage_collections_path unless Rails.configuration.bulk_updates_enabled
  end

  def umm_s_enabled?
    redirect_to manage_collections_path unless Rails.configuration.umm_s_enabled
  end

  def authenticated_urs_uid
    session[:urs_uid]
  end

  def get_user_info
    user = {}
    user[:name] = session[:name]
    user[:email] = session[:email_address]
    user
  end

  def set_provider_context_token
    session[:echo_provider_token] = echo_client.get_provider_context_token(token_with_client_id, behalfOfProvider: current_user.provider_id).parsed_body
  end

  # Custom error messaging for Pundit
  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore

    flash[:error] = t("#{policy_name}.#{exception.query}", scope: 'pundit', default: :default)
    redirect_to(request.referrer || manage_collections_path)
  end

  def clear_session_and_token_data
    all_session_keys = LAUNCHPAD_SESSION_KEYS | URS_SESSION_KEYS
    # additional token and login keys
    all_session_keys += %i[echo_provider_token login_method]

    all_session_keys.each { |session_key| session[session_key] = nil }
  end

  def log_all_session_keys
    return if Rails.env.test? || session[:login_method] == 'urs'
    all_session_keys = LAUNCHPAD_SESSION_KEYS | URS_SESSION_KEYS
    # additional token and login keys
    all_session_keys += %i[echo_provider_token login_method]
      all_session_keys_log = all_session_keys.map do |key|
        if key == :launchpad_cookie && !session[key].blank?
          "#{key}: length: #{session[key].length.round(-2)}; snippet: #{session[key].truncate(50)}"
        else
          "#{key}: #{session[key]}"
        end
      end

    Rails.logger.debug '>>>>> logging session keys'
    Rails.logger.debug all_session_keys_log.join("\n")
  end

  def ensure_at_least_one_login_method
    if both_login_methods_off?
      # if both URS and Launchpad login requirements are turned OFF, users cannot
      # be authenticated and cannot access a token or launchpad cookie
      Rails.logger.error('An error has occured. Both URS and Launchpad login feature toggles are OFF. Please check the configuration of environment variables urs_login_required and launchpad_login_required.')

      # clear session information so user is not logged in
      clear_session_and_token_data

      redirect_to root_url and return
    end

    true
  end

  def both_login_methods_off?
    !urs_login_required? && !launchpad_login_required?
  end
  helper_method :both_login_methods_off?

  def both_login_methods_on?
    urs_login_required? && launchpad_login_required?
  end
  helper_method :both_login_methods_on?

  def launchpad_cookie_name
    Rails.configuration.launchpad_cookie_name
  end
end
