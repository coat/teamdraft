# frozen_string_literal: true

class Admin::SeasonsController < Admin::BaseController
  before_action :load_season, only: [:show, :edit, :update, :activate, :toggle_sync_pause, :switch_provider]

  def index
    pagy, seasons = pagy(Season.includes(:sport).order("sports.key, seasons.year DESC"))
    render Views::Admin::Seasons::Index.new(seasons: seasons, pagy: pagy)
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
        status: :unprocessable_content
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
        status: :unprocessable_content
    end
  end

  def activate
    Seasons::Activate.call(season: @season)
    redirect_to admin_seasons_path, notice: "Activated #{@season.label}."
  end

  def toggle_sync_pause
    @season.update!(sync_paused: !@season.sync_paused?)
    label = @season.sync_paused? ? "paused" : "resumed"
    redirect_to admin_seasons_path, notice: "#{@season.label} sync #{label}."
  end

  def switch_provider
    new_provider = params[:new_provider].to_s.strip
    unless SportsData::Provider::PROVIDERS.key?(new_provider)
      return redirect_to admin_season_path(@season), alert: "Unknown provider: #{new_provider.inspect}"
    end
    if @season.league_seasons.where(status: "drafting").any?
      return redirect_to admin_season_path(@season),
        alert: "Cannot switch provider while a draft is in progress for this season."
    end

    has_picks = @season.league_seasons.joins(:draft_picks).any?

    @season.update!(
      external_provider: new_provider,
      external_id: params[:new_external_id].presence || @season.external_id
    )

    Sync::GamesJob.perform_later(@season.id, dates: [Date.yesterday, Date.current].map(&:iso8601))
    Scoring::RecomputeJob.perform_later(@season.id) if has_picks

    msg = "Provider switched to #{new_provider}. Re-sync queued"
    msg += " (scoring recompute also queued)" if has_picks
    redirect_to admin_season_path(@season), notice: "#{msg}."
  end

  private

  def load_season
    @season = Season.find(params[:id])
  end

  def sports_options
    Sport.order(:key).pluck(:name, :id)
  end

  def season_params
    permitted = params.require(:season).permit(
      :sport_id, :year, :label, :status,
      :starts_on, :ends_on,
      :external_provider, :external_id,
      round_windows: {}
    )
    prune_blank_round_windows(permitted)
  end

  # The form always submits every round's date pair; drop rounds the admin
  # left fully blank so they read as "window unset" rather than failing
  # the both-dates-required validation.
  def prune_blank_round_windows(permitted)
    windows = permitted[:round_windows]
    return permitted if windows.nil?
    pruned = windows.to_h.reject { |_key, w| w["starts_on"].blank? && w["ends_on"].blank? }
    permitted.merge(round_windows: pruned)
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
