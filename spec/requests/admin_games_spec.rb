# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin games", type: :request do
  it "lists games for the active season" do
    sign_in_admin
    create_nfl_season(team_count: 2)

    get admin_games_path

    expect(response).to have_http_status(:ok)
  end

  def build_game(season, home_idx, away_idx, **attrs)
    teams = season.season_teams.order(:id).to_a
    create(:game, season: season,
      home_season_team: teams[home_idx], away_season_team: teams[away_idx], **attrs)
  end

  def matchup(game)
    "#{game.away_season_team.team.abbreviation} @ #{game.home_season_team.team.abbreviation}"
  end

  it "keeps the selected season in the dropdown" do
    sign_in_admin
    active = create_nfl_season(team_count: 2, year: 2025, status: "active")
    other = create(:season, sport: active.sport, year: 2024, status: "completed")

    get admin_games_path(season_id: other.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(selected="selected" value="#{other.id}"))
  end

  it "narrows the list with filters" do
    sign_in_admin
    season = create_nfl_season(team_count: 4)
    week_one = build_game(season, 0, 1, week: 1)
    week_two = build_game(season, 2, 3, week: 2)

    get admin_games_path(season_id: season.id, week: 2)

    expect(response.body).to include(matchup(week_two))
    expect(response.body).not_to include(matchup(week_one))
  end

  it "sorts by the requested column and direction" do
    sign_in_admin
    season = create_nfl_season(team_count: 4)
    early = build_game(season, 0, 1, starts_at: Time.zone.local(2030, 1, 5, 13))
    late = build_game(season, 2, 3, starts_at: Time.zone.local(2030, 2, 5, 13))

    get admin_games_path(season_id: season.id, sort: "starts_at", dir: "desc")

    expect(response.body.index(matchup(late))).to be < response.body.index(matchup(early))
  end

  it "shrugs off garbage sort params" do
    sign_in_admin
    season = create_nfl_season(team_count: 2)
    build_game(season, 0, 1)

    get admin_games_path(season_id: season.id, sort: "'; DROP TABLE games;--", dir: "sideways")

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
