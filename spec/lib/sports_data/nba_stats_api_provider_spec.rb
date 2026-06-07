# frozen_string_literal: true

require "rails_helper"

RSpec.describe SportsData::NbaStatsApiProvider do
  let(:sport) { create(:sport, :nba) }
  let(:season) { create(:season, sport: sport, year: 2025, external_provider: "nba_stats_api") }

  it "parses regular-season games" do
    stub_request(:get, schedule_url).to_return(json_body(payload(games: [
      game(id: "0022500001", label: "", status: 3, status_text: "Final",
        date: "2025-10-21T23:30:00Z", week: 1,
        home: {id: 1610612752, score: 110}, away: {id: 1610612755, score: 102})
    ])))

    games = described_class.new(season: season).fetch_games

    g = games.find { |x| x.external_id == "0022500001" }
    expect(g.round).to eq("regular_season")
    expect(g.week).to eq(1)
    expect(g.home_team_external_id).to eq("1610612752")
    expect(g.away_team_external_id).to eq("1610612755")
    expect(g.home_score).to eq(110)
    expect(g.status).to eq("final")
    expect(g.starts_at).to eq(Time.iso8601("2025-10-21T23:30:00Z"))
  end

  it "marks scheduled games (gameStatus = 1) as scheduled with nil scores" do
    stub_request(:get, schedule_url).to_return(json_body(payload(games: [
      game(id: "0022500002", label: "", status: 1, status_text: "7:30 pm ET",
        home: {id: 1610612752, score: 0}, away: {id: 1610612755, score: 0})
    ])))

    games = described_class.new(season: season).fetch_games

    expect(games.first.status).to eq("scheduled")
  end

  it "treats postponed games (gameStatus = 3 with blank scores) as scheduled" do
    stub_request(:get, schedule_url).to_return(json_body(payload(games: [
      game(id: "0022500003", label: "", status: 3, status_text: "PPD",
        home: {id: 1610612752, score: nil}, away: {id: 1610612755, score: nil})
    ])))

    games = described_class.new(season: season).fetch_games

    expect(games.first.status).to eq("scheduled")
    expect(games.first.home_score).to be_nil
  end

  it "maps every postseason gameLabel to the right round key" do
    stub_request(:get, schedule_url).to_return(json_body(payload(games: [
      game(id: "1", label: "SoFi Play-In Tournament", status: 3, home: {score: 5}, away: {score: 3}),
      game(id: "2", label: "East First Round", status: 3, home: {score: 5}, away: {score: 3}),
      game(id: "3", label: "West Conf. Semifinals", status: 3, home: {score: 5}, away: {score: 3}),
      game(id: "4", label: "East Conf. Finals", status: 3, home: {score: 5}, away: {score: 3}),
      game(id: "5", label: "NBA Finals", status: 3, home: {score: 5}, away: {score: 3})
    ])))

    games = described_class.new(season: season).fetch_games

    expect(games.map(&:round)).to contain_exactly("play_in", "first_round", "conf_semis", "conf_finals", "finals")
  end

  it "drops preseason, all-star and rising-stars games" do
    stub_request(:get, schedule_url).to_return(json_body(payload(games: [
      game(id: "p1", label: "Preseason", status: 3, home: {score: 1}, away: {score: 1}),
      game(id: "a1", label: "All-Star", status: 3, home: {score: 1}, away: {score: 1}),
      game(id: "a2", label: "All-Star Championship", status: 3, home: {score: 1}, away: {score: 1}),
      game(id: "r1", label: "Rising Stars Semifinal", status: 3, home: {score: 1}, away: {score: 1}),
      game(id: "keep", label: "", status: 3, home: {score: 1}, away: {score: 1})
    ])))

    games = described_class.new(season: season).fetch_games

    expect(games.map(&:external_id)).to eq(["keep"])
  end

  it "filters by dates when dates: is given" do
    stub_request(:get, schedule_url).to_return(json_body(payload(games: [
      game(id: "d1", label: "", status: 3, date: "2025-12-25T20:00:00Z", home: {score: 4}, away: {score: 2}),
      game(id: "d2", label: "", status: 3, date: "2025-12-26T03:00:00Z", home: {score: 4}, away: {score: 2}),
      game(id: "d3", label: "", status: 3, date: "2025-12-27T20:00:00Z", home: {score: 4}, away: {score: 2})
    ])))

    games = described_class.new(season: season).fetch_games(dates: ["2025-12-25", "2025-12-26"])

    expect(games.map(&:external_id)).to contain_exactly("d1", "d2")
  end

  it "filters by rounds when rounds: is given" do
    stub_request(:get, schedule_url).to_return(json_body(payload(games: [
      game(id: "rs", label: "", status: 3, home: {score: 1}, away: {score: 1}),
      game(id: "f", label: "NBA Finals", status: 3, home: {score: 1}, away: {score: 1})
    ])))

    games = described_class.new(season: season).fetch_games(rounds: ["finals"])

    expect(games.map(&:external_id)).to eq(["f"])
  end

  it "raises FetchFailed for unknown rounds" do
    expect { described_class.new(season: season).fetch_games(rounds: ["bogus"]) }
      .to raise_error(SportsData::Provider::FetchFailed, /bogus/)
  end

  it "raises FetchFailed when the payload's seasonYear does not match the season" do
    stub_request(:get, schedule_url).to_return(json_body(payload(season_year: "2026-27", games: [])))

    expect { described_class.new(season: season).fetch_games }
      .to raise_error(SportsData::Provider::FetchFailed, /seasonYear/)
  end

  it "raises FetchFailed on HTTP errors" do
    stub_request(:get, schedule_url).to_return(status: 503, body: "boom")

    expect { described_class.new(season: season).fetch_games }
      .to raise_error(SportsData::Provider::FetchFailed)
  end

  it "sends a Referer header so the CDN does not 403" do
    stub = stub_request(:get, schedule_url)
      .with(headers: {"User-Agent" => "Mozilla/5.0 (compatible; teamdraft/1.0)", "Referer" => "https://www.nba.com/"})
      .to_return(json_body(payload(games: [])))

    described_class.new(season: season).fetch_games

    expect(stub).to have_been_requested
  end

  it "exposes NBA round labels keyed by round_key" do
    provider = described_class.new(season: season)

    expect(provider.round_numbers).to eq(%w[regular_season play_in first_round conf_semis conf_finals finals])
    expect(provider.round_labels).to eq(
      "regular_season" => "Regular Season",
      "play_in" => "Play-In",
      "first_round" => "First Round",
      "conf_semis" => "Conf. Semifinals",
      "conf_finals" => "Conf. Finals",
      "finals" => "NBA Finals"
    )
  end

  def schedule_url
    "https://cdn.nba.com/static/json/staticData/scheduleLeagueV2.json"
  end

  def json_body(payload)
    {status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"}}
  end

  def payload(games:, season_year: "2025-26")
    {"leagueSchedule" => {"seasonYear" => season_year, "gameDates" => [{"games" => games}]}}
  end

  def game(id:, label:, status:, status_text: "Final", date: "2025-10-21T23:30:00Z", week: 1, home: {}, away: {})
    {
      "gameId" => id,
      "gameLabel" => label,
      "gameStatus" => status,
      "gameStatusText" => status_text,
      "gameDateTimeUTC" => date,
      "weekNumber" => week,
      "homeTeam" => {"teamId" => home.fetch(:id, 1610612752), "score" => home[:score]},
      "awayTeam" => {"teamId" => away.fetch(:id, 1610612755), "score" => away[:score]}
    }
  end
end
