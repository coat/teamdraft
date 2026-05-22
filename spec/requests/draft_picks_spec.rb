# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Draft picks", type: :request do
  it "owner can record a pick" do
    season = create_nfl_season(team_count: 4)
    league = create_league_via_http(draft_mode: "manual")
    start_drafting!(league.current_league_season)
    season_team = season.season_teams.first

    expect {
      post league_draft_picks_path(league), params: {season_team_id: season_team.id}
    }.to change(DraftPick, :count).by(1)
    # Mid-draft picks redirect back to the draft room.
    expect(response).to redirect_to(league_draft_path(league))
  end

  it "non-owner gets bounced in manual mode" do
    # Create league out-of-band so this test session has no owner cookie,
    # then claim Bob's seat - Bob becomes the only authenticated participant.
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season, draft_mode: "manual").first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    season_team = season.season_teams.first

    expect {
      post league_draft_picks_path(league), params: {season_team_id: season_team.id}
    }.not_to change(DraftPick, :count)

    follow_redirect!
    expect(response.body).to include("Only the league owner")
  end
end
