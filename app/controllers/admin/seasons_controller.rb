# frozen_string_literal: true

class Admin::SeasonsController < Admin::BaseController
  before_action :load_season, only: [:show, :edit, :update, :activate]

  def index
    seasons = Season.includes(:sport).order("sports.key, seasons.year DESC")
    render Views::Admin::Seasons::Index.new(seasons: seasons)
  end

  def show
    render Views::Admin::Seasons::Show.new(season: @season, stats: season_stats)
  end

  def new
    season = Season.new(year: Date.current.year, status: "upcoming")
    render Views::Admin::Seasons::New.new(season: season, sports: sports_options)
  end

  def create
    season = Season.new(season_params)
    if season.save
      Seasons::PopulateTeams.call(season: season)
      redirect_to admin_seasons_path, notice: "Created #{season.label}."
    else
      render Views::Admin::Seasons::New.new(season: season, sports: sports_options),
        status: :unprocessable_entity
    end
  end

  def edit
    render Views::Admin::Seasons::Edit.new(season: @season, sports: sports_options)
  end

  def update
    if @season.update(season_params)
      redirect_to admin_seasons_path, notice: "Updated #{@season.label}."
    else
      render Views::Admin::Seasons::Edit.new(season: @season, sports: sports_options),
        status: :unprocessable_entity
    end
  end

  def activate
    Seasons::Activate.call(season: @season)
    redirect_to admin_seasons_path, notice: "Activated #{@season.label}."
  end

  private

  def load_season
    @season = Season.find(params[:id])
  end

  def sports_options
    Sport.order(:key).pluck(:name, :id)
  end

  def season_params
    params.require(:season).permit(
      :sport_id, :year, :label, :status,
      :starts_on, :ends_on,
      :external_provider, :external_id
    )
  end

  def season_stats
    {
      games: @season.games.count,
      games_final: @season.games.where(status: "final").count,
      scoring_events: ScoringEvent.joins(:season_team).where(season_teams: {season_id: @season.id}).count,
      league_seasons: @season.league_seasons.count
    }
  end
end
