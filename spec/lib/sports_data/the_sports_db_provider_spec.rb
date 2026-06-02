# frozen_string_literal: true

require "rails_helper"

RSpec.describe SportsData::TheSportsDbProvider do
  it "parses regular-season games" do
    season = create_nfl_season(team_count: 2)
    stub_all_rounds(season, events_by_round: {
      "1" => [event(id: "1001", round: "1", home_score: "21", away_score: "14", status: "Match Finished")]
    })
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
    stub_all_rounds(season, events_by_round: {
      "2" => [event(id: "1002", round: "2", home_score: nil, away_score: nil, status: "Not Started")]
    })
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games

    sched = games.find { |g| g.external_id == "1002" }
    expect(sched.status).to eq("scheduled")
    expect(sched.home_score).to be_nil
  end

  it "treats postponed/cancelled games (Match Finished with no scores) as scheduled" do
    season = create_nfl_season(team_count: 2)
    stub_all_rounds(season, events_by_round: {
      "1" => [event(id: "1099", round: "1", home_score: nil, away_score: nil, status: "Match Finished")]
    })
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games

    expect(games.first.status).to eq("scheduled")
    expect(games.first.home_score).to be_nil
  end

  it "maps the championship round to championship" do
    season = create_nfl_season(team_count: 2)
    stub_all_rounds(season, events_by_round: {
      "200" => [event(id: "1003", round: "200", home_score: "10", away_score: "9", status: "Match Finished")]
    })
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games

    bowl = games.find { |g| g.external_id == "1003" }
    expect(bowl.round).to eq("championship")
    expect(bowl.week).to be_nil
  end

  it "does not request preseason rounds" do
    season = create_nfl_season(team_count: 2)
    stub_all_rounds(season, events_by_round: {})

    SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key").fetch_games

    expect(WebMock).not_to have_requested(:get, /eventsround\.php.*[?&]r=500/)
  end

  it "only fetches the requested rounds when rounds: is given" do
    season = create_nfl_season(team_count: 2)
    stub_request(:get, round_url(season, "1")).to_return(
      status: 200,
      body: {"events" => [event(id: "2001", round: "1", home_score: "7", away_score: "3", status: "Match Finished")]}.to_json,
      headers: {"Content-Type" => "application/json"}
    )
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    games = provider.fetch_games(rounds: ["1"])

    expect(games.map(&:external_id)).to eq(["2001"])
    SportsData::TheSportsDbProvider.round_numbers_for("nfl").reject { |r| r == "1" }.each do |round|
      expect(WebMock).not_to have_requested(:get, round_url(season, round))
    end
  end

  it "raises when asked to fetch an unknown round" do
    season = create_nfl_season(team_count: 2)
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    expect { provider.fetch_games(rounds: ["999"]) }.to raise_error(SportsData::Provider::FetchFailed, /999/)
  end

  it "fetches games for each date when dates: is given" do
    season = create_nfl_season(team_count: 2)
    stub_request(:get, "https://www.thesportsdb.com/api/v1/json/test-key/eventsday.php?d=2026-05-15&l=4391").to_return(
      status: 200,
      body: {"events" => [event(id: "D1", round: "10", home_score: "21", away_score: "14", status: "Match Finished")]}.to_json,
      headers: {"Content-Type" => "application/json"}
    )
    stub_request(:get, "https://www.thesportsdb.com/api/v1/json/test-key/eventsday.php?d=2026-05-16&l=4391").to_return(
      status: 200,
      body: {"events" => [event(id: "D2", round: "10", home_score: nil, away_score: nil, status: "Not Started")]}.to_json,
      headers: {"Content-Type" => "application/json"}
    )

    games = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key").fetch_games(dates: ["2026-05-15", "2026-05-16"])

    expect(games.map(&:external_id)).to contain_exactly("D1", "D2")
    expect(games.map(&:status)).to contain_exactly("final", "scheduled")
  end

  it "labels MLB regular-season games (intRound=0) but leaves week nil" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025)
    stub_request(:get, "https://www.thesportsdb.com/api/v1/json/test-key/eventsday.php?d=2025-04-15&l=4424").to_return(
      status: 200,
      body: {"events" => [event(id: "M1", round: "0", home_score: "5", away_score: "3", status: "Match Finished")]}.to_json,
      headers: {"Content-Type" => "application/json"}
    )

    games = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key").fetch_games(dates: ["2025-04-15"])

    expect(games.size).to eq(1)
    expect(games.first.round).to eq("regular_season")
    expect(games.first.week).to be_nil
  end

  it "maps MLB playoff rounds and intRound=0 to regular_season" do
    sport = create(:sport, :mlb)
    season = create(:season, sport: sport, year: 2025, external_id: "mlb-2025")
    create(:team, sport: sport, external_id: "TH")
    create(:team, sport: sport, external_id: "TA")
    rounds = SportsData::TheSportsDbProvider.round_numbers_for("mlb")
    expect(rounds).to contain_exactly("0", "160", "125", "150", "200")
    rounds.each do |round|
      stub_request(:get, mlb_round_url(season, round)).to_return(
        status: 200,
        body: {"events" => [event(id: "mlb-#{round}", round: round, home_score: "5", away_score: "3", status: "Match Finished")]}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
    end

    games = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key").fetch_games

    expect(games.map(&:round)).to contain_exactly("regular_season", "wildcard", "division_series", "lcs", "world_series")
    expect(games.map(&:week).uniq).to eq([nil])
  end

  it "raises on HTTP errors" do
    season = create_nfl_season(team_count: 2)
    stub_request(:get, round_url(season, "1")).to_return(status: 500, body: "boom")
    provider = SportsData::TheSportsDbProvider.new(season: season, api_key: "test-key")

    expect { provider.fetch_games }.to raise_error(SportsData::Provider::FetchFailed)
  end

  def round_url(season, round)
    "https://www.thesportsdb.com/api/v1/json/test-key/eventsround.php?id=4391&r=#{round}&s=#{season.year}"
  end

  def mlb_round_url(season, round)
    "https://www.thesportsdb.com/api/v1/json/test-key/eventsround.php?id=4424&r=#{round}&s=#{season.year}"
  end

  def stub_all_rounds(season, events_by_round:)
    SportsData::TheSportsDbProvider.round_numbers_for("nfl").each do |round|
      stub_request(:get, round_url(season, round)).to_return(
        status: 200,
        body: {"events" => events_by_round.fetch(round, [])}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
    end
  end

  def event(id:, round:, home_score:, away_score:, status:)
    {
      "idEvent" => id, "idHomeTeam" => "T1", "idAwayTeam" => "T2",
      "intHomeScore" => home_score, "intAwayScore" => away_score,
      "dateEvent" => "2025-09-07", "strTime" => "17:00:00",
      "intRound" => round, "strStatus" => status
    }
  end
end
