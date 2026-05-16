# frozen_string_literal: true

class SeasonsController < ApplicationController
  def index
    seasons = Season.includes(:sport).order(Arel.sql("sports.key, seasons.year DESC")).references(:sport)
    render Views::Seasons::Index.new(seasons: seasons)
  end

  def show
    season = Season.includes(:sport, season_teams: :team).find(params[:id])
    league_seasons = season.league_seasons
      .joins(:league).where(leagues: {private: false})
      .includes(:league, :participants).order("leagues.name")
    render Views::Seasons::Show.new(season: season, league_seasons: league_seasons)
  end
end
