# frozen_string_literal: true

class TeamsController < ApplicationController
  def show
    season = Season.find(params[:season_id])
    season_team = season.season_teams
      .joins(:team)
      .includes(:team, home_games: [away_season_team: :team], away_games: [home_season_team: :team])
      .find_by!(teams: {slug: params[:slug]})

    games = (season_team.home_games.to_a + season_team.away_games.to_a)
      .sort_by { |g| [g.week || 999, g.kickoff_at || Time.at(0)] }

    render Views::Teams::Show.new(season: season, season_team: season_team, games: games)
  end
end
