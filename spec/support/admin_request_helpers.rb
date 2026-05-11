# frozen_string_literal: true

module AdminRequestHelpers
  def sign_in_admin(email: "admin@example.com")
    post registration_path, params: {
      user: {email_address: email, password: "supersecret", password_confirmation: "supersecret"}
    }
    User.find_by!(email_address: email).tap { |u| u.update!(admin: true) }
  end
end

RSpec.configure do |config|
  config.include AdminRequestHelpers, type: :request
end
