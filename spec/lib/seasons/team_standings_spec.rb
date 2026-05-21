# frozen_string_literal: true

require "rails_helper"

RSpec.describe Seasons::TeamStandings do
  it "tallies regular-season and playoff records from final games" do
    season = create_nfl_season(team_count: 2)
    team_a, team_b = season.season_teams.first(2)
    create(:game, :final,
      season: season, home_season_team: team_a, away_season_team: team_b,
      home_score: 21, away_score: 14, round: "regular_season")
    create(:game, :final,
      season: season, home_season_team: team_b, away_season_team: team_a,
      home_score: 30, away_score: 28, round: "divisional", week: 19)

    rows = Seasons::TeamStandings.call(season: season)

    row_a = rows.find { |r| r.season_team == team_a }
    row_b = rows.find { |r| r.season_team == team_b }
    expect([row_a.reg_w, row_a.reg_l, row_a.reg_t]).to eq([1, 0, 0])
    expect([row_b.reg_w, row_b.reg_l, row_b.reg_t]).to eq([0, 1, 0])
    expect([row_a.po_w, row_a.po_l]).to eq([0, 1])
    expect([row_b.po_w, row_b.po_l]).to eq([1, 0])
  end

  it "ignores non-final games" do
    season = create_nfl_season(team_count: 2)
    team_a, team_b = season.season_teams.first(2)
    create(:game,
      season: season, home_season_team: team_a, away_season_team: team_b,
      status: "scheduled", round: "regular_season")

    rows = Seasons::TeamStandings.call(season: season)

    expect(rows.map(&:reg_w)).to all(eq(0))
    expect(rows.map(&:reg_l)).to all(eq(0))
  end

  it "computes default points using the sport's base scoring rules" do
    season = create_nfl_season(team_count: 2)
    team_a, team_b = season.season_teams.first(2)
    game = create(:game, :final,
      season: season, home_season_team: team_a, away_season_team: team_b,
      home_score: 21, away_score: 14, round: "regular_season")
    ScoringEvent.create!(season_team: team_a, event_type: "regular_win", occurred_at: Time.current)
    ScoringEvent.create!(season_team: team_a, game: game, event_type: "regular_win", occurred_at: 1.hour.ago)

    rows = Seasons::TeamStandings.call(season: season)

    row_a = rows.find { |r| r.season_team == team_a }
    expected = Scoring::Rules.for(season.sport).points_for("regular_win") * 2
    expect(row_a.points).to eq(expected)
    expect(rows.first).to eq(row_a)
  end
end
