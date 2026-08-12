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
    filters = [
      :sport_id, :year, :label, :status,
      :starts_on, :ends_on,
      :external_provider, :external_id
    ]
    windows_filter = round_windows_filter
    filters << {round_windows: windows_filter} if windows_filter.any?
    prune_blank_round_windows(params.require(:season).permit(*filters))
  end

  # round_windows is a map of playoff round key => date pair, and the round
  # keys vary by sport, so the nested filter has to be built from the sport's
  # playoff rules instead of being listed literally. Permitting the round keys
  # explicitly (rather than an open-ended hash) keeps anything else the form
  # didn't ask for out of the jsonb column.
  def round_windows_filter
    sport_id = submitted_sport_id || @season&.sport_id
    return {} if sport_id.blank?
    ScoringRule.where(sport_id: sport_id, kind: "playoff_appearance")
      .pluck(:round_key).compact
      .index_with { [:starts_on, :ends_on] }
  end

  # The sport select can move a season to another sport in the same request
  # that sets its windows, so prefer the submitted id - but only when it's a
  # scalar, since a nested value here isn't an id at all.
  def submitted_sport_id
    value = params.dig(:season, :sport_id)
    value.to_s.presence if value.is_a?(String) || value.is_a?(Integer)
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
