# frozen_string_literal: true

require "rails_helper"

RSpec.describe "League edit", type: :request do
  it "redirects cookie-only owners to a sign-up CTA" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")

    get edit_league_path(league)

    expect(response).to redirect_to(league_path(league))
    follow_redirect!
    expect(response.body).to include("Sign in as the league owner")
  end

  it "lets the signed-in owner rename and reslug the league" do
    create_nfl_season(team_count: 4)
    create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    league = League.last
    old_slug = league.slug

    patch league_path(league), params: {league: {name: "Alice's Big Draft", slug_candidate: "renamed-thing"}}

    expect(response).to redirect_to(league_path(league.reload))
    expect(league.name).to eq("Alice's Big Draft")
    expect(league.slug).to eq("renamed-thing")

    # Old slug still resolves via friendly_id history.
    get "/leagues/#{old_slug}"
    expect(response).to have_http_status(:moved_permanently)
    follow_redirect!
    expect(request.path).to eq(league_path(league))
  end

  it "blocks non-owners with accounts" do
    # Create league out-of-band so Alice's owner cookie never enters this
    # test session. Then Bob claims his seat and signs up — only Bob's
    # claim token is in the cookie.
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    post registration_path, params: {
      user: {email_address: "bob@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }

    get edit_league_path(league)

    expect(response).to redirect_to(league_path(league))
  end
end
