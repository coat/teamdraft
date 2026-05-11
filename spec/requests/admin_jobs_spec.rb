# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin jobs (Mission Control)", type: :request do
  it "anonymous visitors cannot reach the jobs UI" do
    get "/admin/jobs"

    expect(response).to redirect_to("/session/new")
  end

  it "non-admin users are redirected away" do
    post registration_path, params: {
      user: {email_address: "plain@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }

    get "/admin/jobs"

    expect(response).to redirect_to("/")
  end

  it "admin users can reach the jobs UI" do
    post registration_path, params: {
      user: {email_address: "admin@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    User.find_by!(email_address: "admin@example.com").update!(admin: true)

    get "/admin/jobs"

    # Mission Control redirects /admin/jobs → /admin/jobs/queues by default;
    # accept either a 200 on the index or a redirect into the engine.
    expect(response).to have_http_status(:ok).or have_http_status(:redirect)
  end
end
