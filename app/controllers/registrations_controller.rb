# frozen_string_literal: true

class RegistrationsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    render Views::Registrations::New.new(user: User.new)
  end

  def create
    user = Users::SignUp.call(
      email_address: params.dig(:user, :email_address),
      password: params.dig(:user, :password),
      password_confirmation: params.dig(:user, :password_confirmation),
      claim_tokens: participant_claims.tokens
    )
    start_new_session_for(user)
    redirect_to after_authentication_url, notice: "Account created. Welcome!"
  rescue ActiveRecord::RecordInvalid => e
    render Views::Registrations::New.new(user: e.record),
      status: :unprocessable_entity
  end
end
