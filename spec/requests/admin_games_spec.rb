# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin games", type: :request do
  it "lists games for the active season" do
    sign_in_admin
    create_nfl_season(team_count: 2)

    get admin_games_path

    expect(response).to have_http_status(:ok)
  end

  it "manually finalizes a game and queues recompute" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)
    home, away = season.season_teams.first(2)
    game = create(:game, season: season, home_season_team: home, away_season_team: away)

    expect {
      patch admin_game_path(game), params: {
        game: {status: "final", home_score: 24, away_score: 17, round: "regular_season", week: 1, starts_at: game.starts_at}
      }
    }.to have_enqueued_job(Scoring::RecomputeJob).with(season.id)

    game.reload
    expect(game.status).to eq("final")
    expect(game.home_score).to eq(24)
  end
end
