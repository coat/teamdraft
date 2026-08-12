# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin syncs", type: :request do
  it "queues a games sync" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    expect { post admin_syncs_path, params: {kind: "games", season_id: season.id} }
      .to have_enqueued_job(Sync::GamesJob).with(season.id, rounds: nil)

    expect(response).to redirect_to(admin_root_path)
  end

  it "queues a scoring recompute" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    expect { post admin_syncs_path, params: {kind: "scoring", season_id: season.id} }
      .to have_enqueued_job(Scoring::RecomputeJob).with(season.id)
  end

  it "rejects unknown kinds" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    post admin_syncs_path, params: {kind: "garbage", season_id: season.id}

    expect(response).to redirect_to(admin_root_path)
    follow_redirect!
    expect(response.body).to include("Unknown sync kind")
  end

  it "returns to the season page when return_to names it" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    post admin_syncs_path, params: {
      kind: "scoring", season_id: season.id, return_to: "season"
    }

    expect(response).to redirect_to(admin_season_path(season))
  end

  it "falls back to the dashboard for an unknown return_to" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    post admin_syncs_path, params: {
      kind: "scoring", season_id: season.id, return_to: "https://evil.example"
    }

    expect(response).to redirect_to(admin_root_path)
  end

  # `redirect_to` is the param the old path-echoing version honored; it's
  # passed here to prove it no longer has any effect.
  it "never redirects off-site even when handed a URL" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    ["//evil.example", "/admin.evil.example", "https://evil.example/admin"].each do |target|
      post admin_syncs_path, params: {
        kind: "scoring", season_id: season.id, return_to: target, redirect_to: target
      }

      expect(response).to redirect_to(admin_root_path)
    end
  end

  it "queues a date-range games sync" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    expect {
      post admin_syncs_path, params: {
        kind: "games", season_id: season.id,
        dates_from: "2026-05-15", dates_to: "2026-05-17",
        return_to: "season"
      }
    }.to have_enqueued_job(Sync::GamesJob).with(season.id, dates: %w[2026-05-15 2026-05-16 2026-05-17])

    expect(response).to redirect_to(admin_season_path(season))
  end

  it "rejects an inverted date range" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    expect {
      post admin_syncs_path, params: {
        kind: "games", season_id: season.id,
        dates_from: "2026-05-17", dates_to: "2026-05-15",
        return_to: "season"
      }
    }.not_to have_enqueued_job(Sync::GamesJob)

    expect(flash[:alert]).to match(/end date must be on or after/i)
  end

  it "rejects a date range longer than 60 days" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    expect {
      post admin_syncs_path, params: {
        kind: "games", season_id: season.id,
        dates_from: "2026-01-01", dates_to: "2026-04-01",
        return_to: "season"
      }
    }.not_to have_enqueued_job(Sync::GamesJob)

    expect(flash[:alert]).to match(/too large/i)
  end

  it "rejects malformed dates" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)

    post admin_syncs_path, params: {
      kind: "games", season_id: season.id,
      dates_from: "not-a-date", dates_to: "2026-05-15",
      return_to: "season"
    }

    expect(flash[:alert]).to match(/invalid date/i)
  end
end
