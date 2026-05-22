# frozen_string_literal: true

require "rails_helper"

RSpec.describe Standings::Calculate do
  it "ranks Alice ahead when her drafted teams have scored more" do
    season = create_nfl_season(team_count: 2)
    ls = create(:league_season, season: season)
    alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
    bob = create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
    alice_team, bob_team = season.season_teams.first(2)

    DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)
    DraftPick.create!(league_season: ls, participant: bob, season_team: bob_team, pick_number: 2)
    game = create(:game, :final,
      season: season, home_season_team: alice_team, away_season_team: bob_team,
      home_score: 21, away_score: 14)
    ScoringEvent.create!(season_team: alice_team, event_type: "regular_win", occurred_at: Time.current)
    ScoringEvent.create!(season_team: alice_team, game: game, event_type: "regular_win", occurred_at: 1.hour.ago)

    rows = Standings::Calculate.call(league_season: ls)

    expect(rows.map { |r| r.participant.display_name }).to eq(["Alice", "Bob"])
    expect(rows.first.total_points).to eq(2)
    expect(rows.last.total_points).to eq(0)
  end

  it "resolves point values from the league_season's per-rule overrides" do
    season = create_nfl_season(team_count: 2)
    ls = create(:league_season, season: season)
    alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
    bob = create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
    alice_team, bob_team = season.season_teams.first(2)
    DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)
    DraftPick.create!(league_season: ls, participant: bob, season_team: bob_team, pick_number: 2)

    ScoringEvent.create!(season_team: alice_team, event_type: "regular_win", occurred_at: Time.current)

    rule = season.sport.scoring_rules.find_by(event_type: "regular_win")
    ls.scoring_rule_overrides.find_by(scoring_rule: rule).update!(points: 7)

    rows = Standings::Calculate.call(league_season: ls)

    alice_row = rows.find { |r| r.participant == alice }
    expect(alice_row.total_points).to eq(7)
    expect(alice_row.teams.first.events).to eq({"regular_win" => 7})
  end

  it "leaves other leagues' standings unchanged when one league customizes its rules" do
    season = create_nfl_season(team_count: 2)
    alice_team, _ = season.season_teams.first(2)

    ls_a = create(:league_season, season: season)
    alice = create(:participant, :owner, league_season: ls_a, draft_position: 1)
    create(:participant, league_season: ls_a, draft_position: 2)
    DraftPick.create!(league_season: ls_a, participant: alice, season_team: alice_team, pick_number: 1)

    ls_b = create(:league_season, season: season)
    carol = create(:participant, :owner, league_season: ls_b, draft_position: 1)
    create(:participant, league_season: ls_b, draft_position: 2)
    DraftPick.create!(league_season: ls_b, participant: carol, season_team: alice_team, pick_number: 1)

    ScoringEvent.create!(season_team: alice_team, event_type: "regular_win", occurred_at: Time.current)

    rule = season.sport.scoring_rules.find_by(event_type: "regular_win")
    ls_a.scoring_rule_overrides.find_by(scoring_rule: rule).update!(points: 5)

    rows_a = Standings::Calculate.call(league_season: ls_a)
    rows_b = Standings::Calculate.call(league_season: ls_b)

    expect(rows_a.find { |r| r.participant == alice }.total_points).to eq(5)
    expect(rows_b.find { |r| r.participant == carol }.total_points).to eq(1)
  end
end
