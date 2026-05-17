# frozen_string_literal: true

require "rails_helper"

RSpec.describe "League invite verification", type: :request do
  it "does not show the seat picker to an unverified visitor" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first

    get league_path(league)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Are you Bob?")
    expect(response.body).to include("Have an invite code?")
  end

  it "auto-claims the lone open seat when verifying via the ?invite= query string" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    bob_seat = league.participants.find_by(draft_position: 2)

    get league_path(league, invite: league.current_league_season.invite_code)

    expect(response).to redirect_to(league_path(league))
    expect(bob_seat.reload.joined_at).to be_present
    follow_redirect!
    # When both seats are claimed the draft starts and /leagues/:id
    # redirects claimed viewers to /draft. Either way, the welcome flash
    # is present on the final rendered page.
    follow_redirect! if response.redirect?
    expect(flash[:notice].to_s + response.body).to include("Welcome, Bob")
    expect(response.body).not_to include("Are you Bob?")
  end

  it "rejects a wrong code with a flash and keeps the picker hidden" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first

    post verify_invite_league_path(league), params: {code: "nope-nope-1"}

    expect(response).to redirect_to(league_path(league))
    follow_redirect!
    expect(response.body).to include("didn&#39;t match").or include("didn't match")
    expect(response.body).not_to include("Yes, that's me")
  end

  it "blocks a direct POST to claim without verification" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    bob_seat = league.participants.find_by(draft_position: 2)

    post claim_league_path(league), params: {seat_id: bob_seat.id}

    expect(response).to redirect_to(league_path(league))
    expect(bob_seat.reload.joined_at).to be_nil
  end

  it "claims the lone open seat as soon as the code is verified via the form" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    bob_seat = league.participants.find_by(draft_position: 2)
    code = league.current_league_season.invite_code

    post verify_invite_league_path(league), params: {code: code}

    expect(bob_seat.reload.joined_at).to be_present
  end
end
