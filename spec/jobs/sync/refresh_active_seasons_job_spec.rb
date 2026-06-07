# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sync::RefreshActiveSeasonsJob do
  include ActiveJob::TestHelper

  def enqueued_games_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == Sync::GamesJob }
  end

  it "enqueues a GamesJob for active seasons that are due to sync" do
    sport = create(:sport, :nfl)
    # last_synced_at is nil on both, so the overnight fallback fires.
    active1 = create(:season, sport: sport, status: "active", external_id: "n-2026")
    active2 = create(:season, sport: create(:sport, :mlb), status: "active", external_id: "m-2026")
    create(:season, sport: sport, status: "completed", external_id: "n-2024")
    create(:season, sport: sport, status: "upcoming", external_id: "n-2027")

    Sync::RefreshActiveSeasonsJob.perform_now

    expect(enqueued_games_jobs.map { |j| j[:args].first }).to contain_exactly(active1.id, active2.id)
    expect(enqueued_games_jobs).to all(satisfy { |j| j[:args].last["dates"] == [Date.yesterday.iso8601, Date.current.iso8601] })
  end

  it "skips active seasons that have no external_id" do
    sport = create(:sport, :nfl)
    create(:season, sport: sport, status: "active", external_id: nil)

    Sync::RefreshActiveSeasonsJob.perform_now

    expect(enqueued_games_jobs).to be_empty
  end

  it "skips active seasons whose schedule is idle and that synced recently" do
    season = create_nfl_season(status: "active", external_id: "n-2026", last_synced_at: 10.minutes.ago)
    home, away = season.season_teams.first(2)
    create(:game, season: season, home_season_team: home, away_season_team: away,
      starts_at: 3.days.from_now)

    Sync::RefreshActiveSeasonsJob.perform_now

    expect(enqueued_games_jobs).to be_empty
  end

  it "enqueues an idle season once its overnight fallback window elapses" do
    season = create_nfl_season(status: "active", external_id: "n-2026", last_synced_at: 4.hours.ago)
    home, away = season.season_teams.first(2)
    create(:game, season: season, home_season_team: home, away_season_team: away,
      starts_at: 3.days.from_now)

    Sync::RefreshActiveSeasonsJob.perform_now

    expect(enqueued_games_jobs.map { |j| j[:args].first }).to contain_exactly(season.id)
  end

  it "enqueues a season with a game inside the start window even when recently synced" do
    season = create_nfl_season(status: "active", external_id: "n-2026", last_synced_at: 1.minute.ago)
    home, away = season.season_teams.first(2)
    create(:game, season: season, home_season_team: home, away_season_team: away,
      starts_at: 15.minutes.from_now)

    Sync::RefreshActiveSeasonsJob.perform_now

    expect(enqueued_games_jobs.map { |j| j[:args].first }).to contain_exactly(season.id)
  end
end
