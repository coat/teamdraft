# frozen_string_literal: true

class TeamsController < ApplicationController
  def show
    season = Season.joins(:sport)
      .includes(:sport)
      .find_by!(sports: {key: params[:sport_key]}, year: params[:year])
    season_team = season.season_teams
      .joins(:team)
      .includes(:team, home_games: [away_season_team: :team], away_games: [home_season_team: :team])
      .find_by!(teams: {slug: params[:slug]})
    return if enforce_canonical_team_url(season, season_team)

    games = (season_team.home_games.to_a + season_team.away_games.to_a)
      .sort_by { |g| [g.week || 999, g.starts_at || Time.at(0)] }

    render Views::Teams::Show.new(season: season, season_team: season_team, games: games)
  end

  def legacy_show
    season = Season.includes(:sport).find(params[:id])
    redirect_to season_team_path(season, slug: params[:slug]), status: :moved_permanently
  end

  private

  # sports.key and teams.slug are citext, so mixed-case URLs resolve too;
  # 301 to the stored-case path instead.
  def enforce_canonical_team_url(season, season_team)
    canonical = season_team_path(season, slug: season_team.team.slug)
    return false if request.path == canonical
    redirect_to canonical, status: :moved_permanently
    true
  end
end
