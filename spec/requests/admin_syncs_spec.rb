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
end
