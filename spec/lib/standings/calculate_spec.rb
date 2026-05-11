# frozen_string_literal: true

require "rails_helper"

RSpec.describe Standings::Calculate do
  it "ranks Alice ahead when her drafted teams have scored more" do
    season = create_nfl_season(team_count: 2)
    league = create(:league, season: season)
    alice = create(:participant, :owner, league: league, display_name: "Alice", draft_position: 1)
    bob = create(:participant, league: league, display_name: "Bob", draft_position: 2)
    alice_team, bob_team = season.season_teams.first(2)

    DraftPick.create!(league: league, participant: alice, season_team: alice_team, pick_number: 1)
    DraftPick.create!(league: league, participant: bob, season_team: bob_team, pick_number: 2)
    game = create(:game, :final,
      season: season, home_season_team: alice_team, away_season_team: bob_team,
      home_score: 21, away_score: 14)
    ScoringEvent.create!(season_team: alice_team, event_type: "regular_win", points: 1, occurred_at: Time.current)
    ScoringEvent.create!(season_team: alice_team, game: game, event_type: "regular_win", points: 1, occurred_at: 1.hour.ago)

    rows = Standings::Calculate.call(league: league)

    expect(rows.map { |r| r.participant.display_name }).to eq(["Alice", "Bob"])
    expect(rows.first.total_points).to eq(2)
    expect(rows.last.total_points).to eq(0)
  end
end
