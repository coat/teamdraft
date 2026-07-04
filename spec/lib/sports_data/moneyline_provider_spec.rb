# frozen_string_literal: true

require "rails_helper"

RSpec.describe SportsData::MoneylineProvider do
  def events_url(from:, to:, page: 1)
    query = URI.encode_www_form(league: "mlb", from:, to:, limit: 100, page:)
    "https://mlapi.bet/v1/events?#{query}"
  end

  def json_body(payload)
    {status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"}}
  end

  def event(id:, home: "New York Yankees", away: "Boston Red Sox",
    start_time: "2026-06-27T23:10:00Z", status: "scheduled",
    home_score: nil, away_score: nil)
    scores = (home_score.nil? && away_score.nil?) ? nil : {"home" => home_score, "away" => away_score}
    {"eventId" => id, "homeTeamName" => home, "awayTeamName" => away,
     "startTime" => start_time, "status" => status, "scores" => scores}
  end

  # Mirrors the real response shape (captured live 2026-07-02): events under
  # "data", pagination under "meta".
  def envelope(events, page: 1, pages: 1, total: nil)
    {"success" => true, "data" => events,
     "meta" => {"count" => events.size, "total" => total || events.size,
                "page" => page, "pages" => pages}}
  end

  let(:sport) { create(:sport, :mlb) }

  it "parses a date-based sync into ParsedGame structs" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-26", to: "2026-06-28"))
      .to_return(json_body(envelope([
        event(id: "ml-001", home: "New York Yankees", away: "Boston Red Sox",
          status: "final", home_score: 5, away_score: 3,
          start_time: "2026-06-26T23:05:00Z"),
        event(id: "ml-002", home: "Los Angeles Dodgers", away: "San Francisco Giants",
          status: "scheduled",
          start_time: "2026-06-27T02:10:00Z")
      ])))

    games = SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-26", "2026-06-27"])

    expect(games.size).to eq(2)
    yankees_game = games.find { |g| g.external_id == "ml-001" }
    expect(yankees_game.home_team_external_id).to eq("147")
    expect(yankees_game.away_team_external_id).to eq("111")
    expect(yankees_game.home_score).to eq(5)
    expect(yankees_game.away_score).to eq(3)
    expect(yankees_game.status).to eq("final")
    expect(yankees_game.round).to eq("regular_season")
    expect(yankees_game.week).to be_nil
  end

  it "marks games as final only when status is final AND both scores are present" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28"))
      .to_return(json_body(envelope([
        event(id: "ml-101", status: "final", home_score: 4, away_score: 2),
        event(id: "ml-102", status: "in_progress", home_score: 3, away_score: 1),
        event(id: "ml-103", status: "scheduled"),
        event(id: "ml-104", status: "final")  # final but no scores (postponed/cancelled)
      ])))

    games = SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"])

    by_id = games.index_by(&:external_id)
    expect(by_id["ml-101"].status).to eq("final")
    expect(by_id["ml-102"].status).to eq("scheduled")
    expect(by_id["ml-103"].status).to eq("scheduled")
    expect(by_id["ml-104"].status).to eq("scheduled")
  end

  it "paginates across multiple pages" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28", page: 1))
      .to_return(json_body(envelope([event(id: "ml-p1")], page: 1, pages: 2, total: 2)))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28", page: 2))
      .to_return(json_body(envelope([event(id: "ml-p2")], page: 2, pages: 2, total: 2)))

    games = SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"])

    expect(games.map(&:external_id)).to contain_exactly("ml-p1", "ml-p2")
  end

  it "silently skips events with unrecognized team names" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28"))
      .to_return(json_body(envelope([
        event(id: "ml-good"),
        event(id: "ml-bad", home: "Unknown FC", away: "Mystery United")
      ])))

    games = SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"])

    expect(games.map(&:external_id)).to eq(["ml-good"])
  end

  it "fetches the full season range when no dates are given" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 27), ends_on: Date.new(2026, 10, 4))
    stub_request(:get, events_url(from: "2026-03-27", to: "2026-10-05"))
      .to_return(json_body(envelope([event(id: "ml-season")])))

    games = SportsData::MoneylineProvider.new(season:).fetch_games

    expect(games.map(&:external_id)).to eq(["ml-season"])
  end

  it "drops events that start before the season begins (spring training)" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-03-20", to: "2026-03-27"))
      .to_return(json_body(envelope([
        event(id: "ml-spring", status: "final", home_score: 7, away_score: 7,
          start_time: "2026-03-20T20:05:00Z"),
        event(id: "ml-opener", start_time: "2026-03-26T23:10:00Z")
      ])))

    games = SportsData::MoneylineProvider.new(season:)
      .fetch_games(dates: ["2026-03-20", "2026-03-26"])

    expect(games.map(&:external_id)).to eq(["ml-opener"])
  end

  it "keeps night games whose UTC date rolls past the requested date (dates are Eastern)" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-20", to: "2026-06-21"))
      .to_return(json_body(envelope([
        # 22:10 ET on 6/20 — 02:10 UTC on 6/21. MLB schedules by Eastern
        # date and mlapi.bet's from/to filter matches it, so a 6/20 sync
        # must keep this game.
        event(id: "ml-night", status: "final", home_score: 8, away_score: 16,
          start_time: "2026-06-21T02:10:00Z")
      ])))

    games = SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-20"])

    expect(games.map(&:external_id)).to eq(["ml-night"])
  end

  it "drops spring games whose UTC date rolls onto opening day (season boundary is Eastern)" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-03-24", to: "2026-03-26"))
      .to_return(json_body(envelope([
        # 20:10 ET on 3/24 — 00:10 UTC on 3/25 (starts_on). Exhibition game
        # the night before opening day must still be rejected.
        event(id: "ml-freeway", status: "final", home_score: 0, away_score: 3,
          start_time: "2026-03-25T00:10:00Z"),
        event(id: "ml-opener", start_time: "2026-03-25T23:10:00Z")
      ])))

    games = SportsData::MoneylineProvider.new(season:)
      .fetch_games(dates: ["2026-03-24", "2026-03-25"])

    expect(games.map(&:external_id)).to eq(["ml-opener"])
  end

  it "raises FetchFailed on HTTP error responses" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28"))
      .to_return(status: 503, body: "Service Unavailable")

    expect { SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"]) }
      .to raise_error(SportsData::Provider::FetchFailed, /503/)
  end

  it "raises FetchFailed on connection-level errors (HTTPX returns ErrorResponse, not an exception)" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28")).to_timeout

    expect { SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"]) }
      .to raise_error(SportsData::Provider::FetchFailed, /request failed/)
  end

  it "raises FetchFailed with a clear message on 429 rate limiting" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28"))
      .to_return(status: 429, headers: {"Retry-After" => "60"})

    expect { SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"]) }
      .to raise_error(SportsData::Provider::FetchFailed, /rate limited/)
  end

  it "raises FetchFailed on 401 unauthorized" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28"))
      .to_return(status: 401, body: '{"error":"Unauthorized"}',
        headers: {"Content-Type" => "application/json"})

    expect { SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"]) }
      .to raise_error(SportsData::Provider::FetchFailed, /401/)
  end

  it "exposes round_numbers and round_labels for the admin UI" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    provider = SportsData::MoneylineProvider.new(season:)

    expect(provider.round_numbers).to eq(["regular_season"])
    expect(provider.round_labels).to eq("regular_season" => "Regular Season")
  end

  it "sends x-api-key header on every request" do
    season = create(:season, sport:, year: 2026, external_provider: "moneyline",
      starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5))
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("MONEYLINE_API_KEY", nil).and_return("ml_live_testkey")
    stub = stub_request(:get, events_url(from: "2026-06-27", to: "2026-06-28"))
      .with(headers: {"x-api-key" => "ml_live_testkey"})
      .to_return(json_body(envelope([])))

    SportsData::MoneylineProvider.new(season:).fetch_games(dates: ["2026-06-27"])

    expect(stub).to have_been_requested
  end
end
