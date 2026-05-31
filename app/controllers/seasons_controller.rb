# frozen_string_literal: true

class SeasonsController < ApplicationController
  def index
    seasons = Season.includes(:sport).order(Arel.sql("sports.key, seasons.year DESC")).references(:sport)
    render Views::Seasons::Index.new(seasons: seasons)
  end

  def show
    season = Season.includes(:sport, season_teams: :team).find(params[:id])
    standings_query = Seasons::StandingsQuery.from_request(season: season, params: params)
    league_leaders = Seasons::LeagueLeaders.call(season: season)
    render Views::Seasons::Show.new(
      season: season,
      standings_query: standings_query,
      league_leaders: league_leaders
    )
  end
end
