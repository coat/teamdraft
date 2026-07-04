# frozen_string_literal: true

require "rails_helper"

RSpec.describe SportsData::MlbStatsApiProvider do
  it "parses regular-season games" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2025", gameTypes: "R,F,D,L,W"))
      .to_return(json_body("dates" => [{"games" => [game(pk: 700001, type: "R", home_id: 147, away_id: 111, home_score: 4, away_score: 2, state: "Final")]}]))

    games = SportsData::MlbStatsApiProvider.new(season: season).fetch_games

    rs = games.find { |g| g.external_id == "700001" }
    expect(rs.round).to eq("regular_season")
    expect(rs.week).to be_nil
    expect(rs.home_team_external_id).to eq("147")
    expect(rs.away_team_external_id).to eq("111")
    expect(rs.home_score).to eq(4)
    expect(rs.status).to eq("final")
  end

  it "marks games without final state as scheduled" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2025", gameTypes: "R,F,D,L,W"))
      .to_return(json_body("dates" => [{"games" => [game(pk: 700002, type: "R", home_id: 147, away_id: 111, state: "Preview")]}]))

    games = SportsData::MlbStatsApiProvider.new(season: season).fetch_games

    sched = games.find { |g| g.external_id == "700002" }
    expect(sched.status).to eq("scheduled")
    expect(sched.home_score).to be_nil
  end

  it "treats postponed/cancelled games (Final with no scores) as scheduled" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2026, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2026", gameTypes: "R,F,D,L,W"))
      .to_return(json_body("dates" => [{"games" => [
        game(pk: 800001, type: "R", state: "Final", coded: "C", home_score: nil, away_score: nil)
      ]}]))

    games = SportsData::MlbStatsApiProvider.new(season: season).fetch_games

    expect(games.first.status).to eq("scheduled")
    expect(games.first.home_score).to be_nil
  end

  it "maps every postseason gameType to the right round key" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2025", gameTypes: "R,F,D,L,W")).to_return(json_body(
      "dates" => [{"games" => [
        game(pk: 1, type: "F", state: "Final", home_score: 5, away_score: 3),
        game(pk: 2, type: "D", state: "Final", home_score: 5, away_score: 3),
        game(pk: 3, type: "L", state: "Final", home_score: 5, away_score: 3),
        game(pk: 4, type: "W", state: "Final", home_score: 5, away_score: 3)
      ]}]
    ))

    games = SportsData::MlbStatsApiProvider.new(season: season).fetch_games

    expect(games.map(&:round)).to contain_exactly("wildcard", "division_series", "lcs", "world_series")
  end

  it "skips unknown gameTypes (spring, exhibition, all-star) without raising" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2025", gameTypes: "R,F,D,L,W")).to_return(json_body(
      "dates" => [{"games" => [
        game(pk: 1, type: "S", state: "Final"),
        game(pk: 2, type: "E", state: "Final"),
        game(pk: 3, type: "A", state: "Final"),
        game(pk: 4, type: "R", state: "Final", home_score: 2, away_score: 1)
      ]}]
    ))

    games = SportsData::MlbStatsApiProvider.new(season: season).fetch_games

    expect(games.map(&:external_id)).to eq(["4"])
  end

  it "fetches a single schedule request for a date range when dates: is given" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(startDate: "2025-04-15", endDate: "2025-04-17", gameTypes: "R,F,D,L,W"))
      .to_return(json_body("dates" => [
        {"games" => [game(pk: 100, type: "R", state: "Final", home_score: 6, away_score: 1)]},
        {"games" => [game(pk: 101, type: "R", state: "Preview")]}
      ]))

    games = SportsData::MlbStatsApiProvider.new(season: season).fetch_games(dates: ["2025-04-15", "2025-04-16", "2025-04-17"])

    expect(games.map(&:external_id)).to contain_exactly("100", "101")
    expect(games.map(&:status)).to contain_exactly("final", "scheduled")
  end

  it "narrows the gameTypes query when rounds: is given" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2025", gameTypes: "W"))
      .to_return(json_body("dates" => [{"games" => [game(pk: 999, type: "W", state: "Final", home_score: 5, away_score: 4)]}]))

    games = SportsData::MlbStatsApiProvider.new(season: season).fetch_games(rounds: ["W"])

    expect(games.map(&:external_id)).to eq(["999"])
    expect(games.first.round).to eq("world_series")
  end

  it "raises FetchFailed for unknown rounds" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")

    expect { SportsData::MlbStatsApiProvider.new(season: season).fetch_games(rounds: ["XX"]) }
      .to raise_error(SportsData::Provider::FetchFailed, /XX/)
  end

  it "raises FetchFailed on HTTP errors" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2025", gameTypes: "R,F,D,L,W")).to_return(status: 503, body: "boom")

    expect { SportsData::MlbStatsApiProvider.new(season: season).fetch_games }
      .to raise_error(SportsData::Provider::FetchFailed)
  end

  it "raises FetchFailed on connection-level errors (HTTPX returns ErrorResponse, not an exception)" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub_request(:get, schedule_url(season: "2025", gameTypes: "R,F,D,L,W")).to_timeout

    expect { SportsData::MlbStatsApiProvider.new(season: season).fetch_games }
      .to raise_error(SportsData::Provider::FetchFailed, /request failed/)
  end

  it "sends a non-bot-flagged User-Agent and JSON Accept header" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")
    stub = stub_request(:get, schedule_url(season: "2025", gameTypes: "R,F,D,L,W"))
      .with(headers: {"User-Agent" => "Mozilla/5.0 (compatible; teamdraft/1.0)", "Accept" => "application/json"})
      .to_return(json_body("dates" => []))

    SportsData::MlbStatsApiProvider.new(season: season).fetch_games

    expect(stub).to have_been_requested
  end

  it "exposes MLB round labels keyed by gameType" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_provider: "mlb_stats_api")

    provider = SportsData::MlbStatsApiProvider.new(season: season)

    expect(provider.round_numbers).to eq(%w[R F D L W])
    expect(provider.round_labels).to eq("R" => "Regular Season", "F" => "Wild Card", "D" => "Division Series", "L" => "LCS", "W" => "World Series")
  end

  def schedule_url(**params)
    query = URI.encode_www_form({sportId: 1}.merge(params))
    "https://statsapi.mlb.com/api/v1/schedule?#{query}"
  end

  def json_body(payload)
    {status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"}}
  end

  def game(pk:, type:, state: "Preview", coded: nil, home_id: 147, away_id: 111, home_score: nil, away_score: nil)
    coded ||= (state == "Final") ? "F" : "P"
    {
      "gamePk" => pk,
      "gameType" => type,
      "gameDate" => "2025-04-15T23:05:00Z",
      "status" => {"abstractGameState" => state, "codedGameState" => coded},
      "teams" => {
        "home" => {"team" => {"id" => home_id, "name" => "Home"}, "score" => home_score},
        "away" => {"team" => {"id" => away_id, "name" => "Away"}, "score" => away_score}
      }
    }
  end
end
