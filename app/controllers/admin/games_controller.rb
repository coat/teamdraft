# frozen_string_literal: true

class Admin::GamesController < Admin::BaseController
  before_action :load_game, only: [:edit, :update]

  def index
    query = Admin::Games::ListQuery.new(params)
    pagy, games = pagy(query.relation)
    render Views::Admin::Games::Index.new(
      query: query,
      games: games,
      all_seasons: Season.order(year: :desc),
      team_options: team_options(query.season),
      round_options: round_options(query.season),
      pagy: pagy
    )
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

  def team_options(season)
    return [] unless season
    season.season_teams.joins(:team).order("teams.name").pluck("teams.name", "season_teams.team_id")
  end

  def round_options(season)
    return [] unless season
    season.games.distinct.order(:round).pluck(:round)
  end

  def load_game
    @game = Game.find(params[:id])
  end

  # Blank score fields ride through as empty strings; ActiveRecord's integer
  # type-cast nils them on assignment, so no manual `.presence` is needed.
  def game_params
    params.require(:game).permit(:status, :home_score, :away_score, :round, :week, :starts_at, :completed_at)
  end
end
