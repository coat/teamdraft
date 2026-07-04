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

  it "adopts a new external_id for an existing game with the same matchup and start time" do
    season = create_nfl_season(team_count: 2)
    home_team, away_team = season.teams.first(2)
    home_team.update!(external_id: "EXT-HOME")
    away_team.update!(external_id: "EXT-AWAY")
    starts_at = Time.utc(2026, 7, 3, 2, 10)
    game = create(:game, season: season,
      home_season_team: season.season_teams.find_by(team: home_team),
      away_season_team: season.season_teams.find_by(team: away_team),
      external_id: "776999", starts_at: starts_at)

    parsed = build_parsed_game(home_team, away_team, external_id: "mlb-ev-123",
      starts_at: starts_at + 1.minute, home_score: 5, away_score: 3)
    Sync::ApplyGames.call(season: season, parsed_games: [parsed])

    expect(season.games.count).to eq(1)
    expect(game.reload.external_id).to eq("mlb-ev-123")
    expect(game.home_score).to eq(5)
    expect(game.starts_at).to eq(starts_at + 1.minute)
  end

  it "updates the same row across a stub-to-real external_id transition" do
    season = create_nfl_season(team_count: 2)
    home_team, away_team = season.teams.first(2)
    home_team.update!(external_id: "EXT-HOME")
    away_team.update!(external_id: "EXT-AWAY")
    starts_at = Time.utc(2026, 7, 4, 2, 11)

    stub = build_parsed_game(home_team, away_team, external_id: "mlb-odds-abc",
      status: "scheduled", home_score: nil, away_score: nil, starts_at: starts_at)
    Sync::ApplyGames.call(season: season, parsed_games: [stub])

    real = build_parsed_game(home_team, away_team, external_id: "mlb-ev-456",
      starts_at: starts_at - 1.minute, home_score: 2, away_score: 1)
    Sync::ApplyGames.call(season: season, parsed_games: [real])

    expect(season.games.count).to eq(1)
    expect(season.games.first.external_id).to eq("mlb-ev-456")
    expect(season.games.first.status).to eq("final")
  end

  it "keeps doubleheader games separate, matching each to the nearest start time" do
    season = create_nfl_season(team_count: 2)
    home_team, away_team = season.teams.first(2)
    home_team.update!(external_id: "EXT-HOME")
    away_team.update!(external_id: "EXT-AWAY")
    home_st = season.season_teams.find_by(team: home_team)
    away_st = season.season_teams.find_by(team: away_team)
    early = Time.utc(2026, 7, 3, 17, 0)
    late = Time.utc(2026, 7, 3, 23, 0)
    game1 = create(:game, season: season, home_season_team: home_st, away_season_team: away_st,
      external_id: "700001", starts_at: early)
    game2 = create(:game, season: season, home_season_team: home_st, away_season_team: away_st,
      external_id: "700002", starts_at: late)

    Sync::ApplyGames.call(season: season, parsed_games: [
      build_parsed_game(home_team, away_team, external_id: "mlb-ev-late", starts_at: late + 5.minutes),
      build_parsed_game(home_team, away_team, external_id: "mlb-ev-early", starts_at: early + 5.minutes)
    ])

    expect(season.games.count).to eq(2)
    expect(game1.reload.external_id).to eq("mlb-ev-early")
    expect(game2.reload.external_id).to eq("mlb-ev-late")
  end

  it "does not fallback-match games with distant start times" do
    season = create_nfl_season(team_count: 2)
    home_team, away_team = season.teams.first(2)
    home_team.update!(external_id: "EXT-HOME")
    away_team.update!(external_id: "EXT-AWAY")
    create(:game, season: season,
      home_season_team: season.season_teams.find_by(team: home_team),
      away_season_team: season.season_teams.find_by(team: away_team),
      external_id: "700003", starts_at: Time.utc(2026, 6, 30, 2, 10))

    parsed = build_parsed_game(home_team, away_team, external_id: "mlb-ev-789",
      starts_at: Time.utc(2026, 7, 3, 2, 10))
    Sync::ApplyGames.call(season: season, parsed_games: [parsed])

    expect(season.games.count).to eq(2)
    expect(season.games.pluck(:external_id)).to contain_exactly("700003", "mlb-ev-789")
  end

  it "skips games whose teams aren't mapped" do
    season = create_nfl_season(team_count: 2)
    parsed = SportsData::ParsedGame.new(
      external_id: "x",
      home_team_external_id: "UNKNOWN-1",
      away_team_external_id: "UNKNOWN-2",
      home_score: nil, away_score: nil,
      starts_at: Time.current, round: "regular_season", week: 1, status: "scheduled"
    )

    result = Sync::ApplyGames.call(season: season, parsed_games: [parsed])

    expect(result.skipped).to eq(1)
    expect(result.upserted).to eq(0)
  end

  def build_parsed_game(home_team, away_team, external_id:, status: "final", home_score: 21, away_score: 14, starts_at: 1.day.ago)
    SportsData::ParsedGame.new(
      external_id: external_id,
      home_team_external_id: home_team.external_id,
      away_team_external_id: away_team.external_id,
      home_score: home_score,
      away_score: away_score,
      starts_at: starts_at,
      round: "regular_season",
      week: 1,
      status: status
    )
  end
end
