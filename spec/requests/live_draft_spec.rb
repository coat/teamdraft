# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Live draft", type: :request do
  it "Bob can't pick when Alice (pick #1) is on the clock" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    season_team = season.season_teams.first

    expect { post league_draft_picks_path(league), params: {season_team_id: season_team.id} }
      .not_to change(DraftPick, :count)

    follow_redirect!
    expect(response.body).to include("not your turn")
  end

  it "Bob can pick on pick #2 (back-and-forth order)" do
    # Bob claims his seat (which fills both seats and transitions the
    # league to drafting). Then submit Alice's pick #1 server-side and let
    # Bob pick #2 over HTTP under his own cookie.
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    Drafts::SubmitPick.call(league: league.reload, season_team: season.season_teams.first)

    expect { post league_draft_picks_path(league), params: {season_team_id: season.season_teams.second.id} }
      .to change(DraftPick, :count).by(1)
  end
end
