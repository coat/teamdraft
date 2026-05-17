# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Signing out", type: :request do
  it "drops claim tokens for participants linked at sign-up time" do
    create_nfl_season(team_count: 4)
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    create_league_via_http(your_name: "Alice", opponent_name: "Bob")

    delete session_path

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Start a draft")
  end

  it "drops claim tokens after sign-in for a returning user with a cookie-only seat" do
    create_nfl_season(team_count: 4)
    User.create!(email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret")
    create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    post session_path, params: {email_address: "alice@example.com", password: "supersecret"}

    delete session_path

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Start a draft")
  end
end
