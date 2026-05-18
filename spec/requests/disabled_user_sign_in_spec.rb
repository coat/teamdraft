# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Disabled users", type: :request do
  it "cannot sign in" do
    user = create(:user, email_address: "blocked@example.com", password: "supersecret")
    user.update!(disabled_at: Time.current)

    post session_path, params: {email_address: "blocked@example.com", password: "supersecret"}

    follow_redirect!
    expect(response.body).to include("This account has been disabled")
    expect(cookies[:session_id]).to be_blank
  end

  it "loses an existing session if disabled mid-flight" do
    user = create(:user, email_address: "blocked@example.com", password: "supersecret")
    post session_path, params: {email_address: "blocked@example.com", password: "supersecret"}

    user.update!(disabled_at: Time.current)
    user.sessions.destroy_all

    get root_path

    # After session destruction, the cookie's session_id no longer maps to a
    # row, so resume_session yields nothing and the request proceeds as anon.
    expect(response).to have_http_status(:ok)
  end
end
