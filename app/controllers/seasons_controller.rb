# frozen_string_literal: true

class SeasonsController < ApplicationController
  def index
    seasons = Season.includes(:sport).order(Arel.sql("sports.key, seasons.year DESC")).references(:sport)
    render Views::Seasons::Index.new(seasons: seasons)
  end

  def show
    season = Season.joins(:sport)
      .includes(:sport, season_teams: :team)
      .find_by!(sports: {key: params[:sport_key]}, year: params[:year])
    return if enforce_canonical_season_url(season)

    standings_query = Seasons::StandingsQuery.from_request(season: season, params: params)
    league_leaders = Seasons::LeagueLeaders.call(season: season)
    render Views::Seasons::Show.new(
      season: season,
      standings_query: standings_query,
      league_leaders: league_leaders
    )
  end

  def legacy_show
    season = Season.includes(:sport).find(params[:id])
    redirect_to season_path(season, **request.query_parameters.symbolize_keys),
      status: :moved_permanently
  end

  private

  # sports.key is citext, so /seasons/MLB/2006 resolves too; 301 to the
  # stored-case key instead (mirrors LeaguesController#enforce_canonical_url).
  def enforce_canonical_season_url(season)
    return false if request.path == season_path(season)
    redirect_to season_path(season, **request.query_parameters.symbolize_keys),
      status: :moved_permanently
    true
  end
end
