# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cross-device login", type: :request do
  it "resolves a participant via the user account when the cookie is fresh" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    expect(league.owner.reload.user_id).to be_present

    # Device 2: clear all cookies, sign in fresh.
    cookies.delete(ParticipantClaims::COOKIE_KEY)
    cookies.delete(:session_id)
    post session_path, params: {email_address: "alice@example.com", password: "supersecret"}

    get league_path(league)

    expect(response.body).not_to include("Are you Bob?")
  end
end
