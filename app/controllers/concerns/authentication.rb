# frozen_string_literal: true

# Auth is opt-in: most pages are anonymous-friendly, so we always resume a
# session if one exists (so `Current.user` is available everywhere) but
# never redirect by default. Controllers that *do* require an account call
# `require_authentication` as a before_action explicitly.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :authenticated?, :current_user
  end

  private

  def authenticated?
    Current.session.present?
  end

  def current_user
    Current.user
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def require_authentication
    return if authenticated?
    session[:return_to_after_authenticating] = request.url
    redirect_to main_app.new_session_path, alert: "Please sign in to continue."
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = {value: session.id, httponly: true, same_site: :lax}
    end
  end

  def terminate_session
    Current.session&.destroy
    Current.session = nil
    cookies.delete(:session_id)
  end
end
