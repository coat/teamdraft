# frozen_string_literal: true

class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
    render Views::Sessions::New.new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))
    if user
      start_new_session_for(user)
      redirect_to after_authentication_url, notice: "Signed in."
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    participant_claims.clear
    terminate_session
    redirect_to root_path, status: :see_other, notice: "Signed out."
  end
end
