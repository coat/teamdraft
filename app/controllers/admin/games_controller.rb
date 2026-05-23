# frozen_string_literal: true

class Admin::GamesController < Admin::BaseController
  before_action :load_game, only: [:edit, :update]

  def index
    season_id = params[:season_id].presence || Season.where(status: "active").pick(:id) || Season.first&.id
    season = season_id && Season.find(season_id)
    scope = if season
      season.games
        .includes(home_season_team: :team, away_season_team: :team)
        .order(Arel.sql("kickoff_at ASC NULLS LAST"))
    else
      Game.none
    end
    pagy, games = pagy(scope)
    render Views::Admin::Games::Index.new(season: season, games: games, all_seasons: Season.order(year: :desc), pagy: pagy)
  end

  def edit
    render Views::Admin::Games::Edit.new(game: @game)
  end

  def update
    if @game.update(game_params)
      if @game.final?
        Scoring::RecomputeJob.perform_later(@game.season_id)
        notice = "Updated. Scoring recompute queued."
      else
        notice = "Updated."
      end
      redirect_to admin_games_path(season_id: @game.season_id), notice: notice
    else
      render Views::Admin::Games::Edit.new(game: @game), status: :unprocessable_entity
    end
  end

  private

  def load_game
    @game = Game.find(params[:id])
  end

  # Blank score fields ride through as empty strings; ActiveRecord's integer
  # type-cast nils them on assignment, so no manual `.presence` is needed.
  def game_params
    params.require(:game).permit(:status, :home_score, :away_score, :round, :week, :kickoff_at, :completed_at)
  end
end
