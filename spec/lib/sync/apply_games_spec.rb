# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sync::ApplyGames do
  it "upserts games keyed by external_id" do
    season = create_nfl_season(team_count: 2)
    home_team, away_team = season.teams.first(2)
    home_team.update!(external_id: "EXT-HOME")
    away_team.update!(external_id: "EXT-AWAY")
    parsed = build_parsed_game(home_team, away_team, external_id: "abc")

    Sync::ApplyGames.call(season: season, parsed_games: [parsed])

    expect(season.games.count).to eq(1)

    Sync::ApplyGames.call(season: season, parsed_games: [build_parsed_game(home_team, away_team, external_id: "abc", home_score: 35)])

    expect(season.games.count).to eq(1)
    expect(season.games.first.home_score).to eq(35)
  end

  it "skips games whose teams aren't mapped" do
    season = create_nfl_season(team_count: 2)
    parsed = SportsData::ParsedGame.new(
      external_id: "x",
      home_team_external_id: "UNKNOWN-1",
      away_team_external_id: "UNKNOWN-2",
      home_score: nil, away_score: nil,
      kickoff_at: Time.current, round: "regular_season", week: 1, status: "scheduled"
    )

    result = Sync::ApplyGames.call(season: season, parsed_games: [parsed])

    expect(result.skipped).to eq(1)
    expect(result.upserted).to eq(0)
  end

  def build_parsed_game(home_team, away_team, external_id:, status: "final", home_score: 21, away_score: 14)
    SportsData::ParsedGame.new(
      external_id: external_id,
      home_team_external_id: home_team.external_id,
      away_team_external_id: away_team.external_id,
      home_score: home_score,
      away_score: away_score,
      kickoff_at: 1.day.ago,
      round: "regular_season",
      week: 1,
      status: status
    )
  end
end
