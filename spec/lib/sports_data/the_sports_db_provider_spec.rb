# frozen_string_literal: true

require "rails_helper"

RSpec.describe SportsData::TheSportsDbProvider do
  it "parses regular-season games" do
    season = create_nfl_season(team_count: 2)
    stub_events_endpoint(season, payload: regular_season_payload)
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games

    rs = games.find { |g| g.external_id == "1001" }
    expect(rs.round).to eq("regular_season")
    expect(rs.week).to eq(1)
    expect(rs.home_score).to eq(21)
    expect(rs.status).to eq("final")
  end

  it "marks games without scores as scheduled" do
    season = create_nfl_season(team_count: 2)
    stub_events_endpoint(season, payload: regular_season_payload)
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games

    sched = games.find { |g| g.external_id == "1002" }
    expect(sched.status).to eq("scheduled")
    expect(sched.home_score).to be_nil
  end

  it "maps the championship round to championship" do
    season = create_nfl_season(team_count: 2)
    stub_events_endpoint(season, payload: regular_season_payload)
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games

    bowl = games.find { |g| g.external_id == "1003" }
    expect(bowl.round).to eq("championship")
    expect(bowl.week).to be_nil
  end

  it "filters out non-real rounds (preseason, pro bowl, etc.)" do
    season = create_nfl_season(team_count: 2)
    stub_events_endpoint(season, payload: regular_season_payload)
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games

    expect(games.map(&:external_id)).not_to include("9999")
  end

  it "raises on HTTP errors" do
    season = create_nfl_season(team_count: 2)
    stub_request(:get, api_url(season)).to_return(status: 500, body: "boom")
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    expect { provider.fetch_games }.to raise_error(SportsData::Provider::FetchFailed)
  end

  def api_url(season)
    "https://www.thesportsdb.com/api/v1/json/test-key/eventsseason.php?id=4391&s=#{season.year}-#{season.year + 1}"
  end

  def stub_events_endpoint(season, payload:)
    stub_request(:get, api_url(season)).to_return(
      status: 200,
      body: payload.to_json,
      headers: {"Content-Type" => "application/json"}
    )
  end

  def regular_season_payload
    {
      "events" => [
        {"idEvent" => "1001", "idHomeTeam" => "T1", "idAwayTeam" => "T2",
         "intHomeScore" => "21", "intAwayScore" => "14",
         "dateEvent" => "2025-09-07", "strTime" => "17:00:00",
         "intRound" => "1", "strStatus" => "Match Finished"},
        {"idEvent" => "1002", "idHomeTeam" => "T3", "idAwayTeam" => "T4",
         "intHomeScore" => nil, "intAwayScore" => nil,
         "dateEvent" => "2025-09-14", "strTime" => "20:20:00",
         "intRound" => "2", "strStatus" => "Not Started"},
        {"idEvent" => "1003", "idHomeTeam" => "T1", "idAwayTeam" => "T2",
         "intHomeScore" => "10", "intAwayScore" => "9",
         "dateEvent" => "2026-02-09", "strTime" => "23:30:00",
         "intRound" => "200", "strStatus" => "Match Finished"},
        {"idEvent" => "9999", "idHomeTeam" => "T5", "idAwayTeam" => "T6",
         "dateEvent" => "2025-08-01",
         "intRound" => "500", "strStatus" => "Match Finished"}
      ]
    }
  end
end
