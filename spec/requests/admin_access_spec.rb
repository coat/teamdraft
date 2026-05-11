# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin access", type: :request do
  it "anonymous visitors are redirected to sign in" do
    get admin_root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "non-admin users are redirected with an alert" do
    sign_up_user("plain@example.com")

    get admin_root_path

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("Admin access required")
  end

  it "admin users see the dashboard" do
    sign_up_user("admin@example.com").update!(admin: true)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Admin")
  end

  def sign_up_user(email)
    post registration_path, params: {
      user: {email_address: email, password: "supersecret", password_confirmation: "supersecret"}
    }
    User.find_by!(email_address: email)
  end
end
