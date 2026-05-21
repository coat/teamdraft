# frozen_string_literal: true

# Per-user team rankings (auto-pick override). Sport is resolved from
# the URL slug; everything else is scoped to current_user.
class RankingsController < ApplicationController
  before_action :require_authentication
  before_action :load_sport, except: [:sports_index]

  def sports_index
    @sports = Sport.active.ordered
    render Views::Rankings::SportsIndex.new(sports: @sports)
  end

  def index
    ranked = current_user.team_rankings
      .where(sport_id: @sport.id)
      .includes(:team)
      .sort_by { |r| r.rank }
    ranked_team_ids = ranked.map(&:team_id)
    unranked = @sport.teams.where.not(id: ranked_team_ids)
      .order(Arel.sql("default_pick_rank NULLS LAST, name ASC"))
    live_drafts_count = current_user.participants
      .joins(:league_season)
      .joins("INNER JOIN seasons ON seasons.id = league_seasons.season_id")
      .where(league_seasons: {status: "drafting"})
      .where(seasons: {sport_id: @sport.id})
      .count
    render Views::Rankings::Index.new(
      sport: @sport, ranked: ranked, unranked: unranked,
      live_drafts_count: live_drafts_count
    )
  end

  def create
    team = @sport.teams.find(params[:team_id])
    UserTeamRanking.transaction do
      max_rank = current_user.team_rankings
        .where(sport_id: @sport.id).maximum(:rank) || 0
      current_user.team_rankings.create!(team: team, sport: @sport, rank: max_rank + 1)
    end
    redirect_to sport_rankings_path(@sport.key), notice: "Added #{team.name} to your ranking."
  rescue ActiveRecord::RecordNotUnique
    redirect_to sport_rankings_path(@sport.key), alert: "#{team.name} is already ranked."
  end

  def destroy
    ranking = current_user.team_rankings.find(params[:id])
    removed_rank = ranking.rank
    UserTeamRanking.transaction do
      UserTeamRanking.connection.execute("SET CONSTRAINTS ALL DEFERRED")
      ranking.destroy!
      current_user.team_rankings
        .where(sport_id: @sport.id)
        .where("rank > ?", removed_rank)
        .update_all("rank = rank - 1")
    end
    redirect_to sport_rankings_path(@sport.key), notice: "Removed #{ranking.team.name}."
  end

  def move_up
    ranking = current_user.team_rankings.find(params[:id])
    neighbor = current_user.team_rankings
      .where(sport_id: @sport.id)
      .where(rank: ...ranking.rank)
      .order(rank: :desc).first
    if neighbor
      swap_ranks(ranking, neighbor)
      redirect_to sport_rankings_path(@sport.key), notice: "Moved #{ranking.team.name} up."
    else
      redirect_to sport_rankings_path(@sport.key), alert: "#{ranking.team.name} is already first."
    end
  end

  def move_down
    ranking = current_user.team_rankings.find(params[:id])
    neighbor = current_user.team_rankings
      .where(sport_id: @sport.id)
      .where("rank > ?", ranking.rank)
      .order(rank: :asc).first
    if neighbor
      swap_ranks(ranking, neighbor)
      redirect_to sport_rankings_path(@sport.key), notice: "Moved #{ranking.team.name} down."
    else
      redirect_to sport_rankings_path(@sport.key), alert: "#{ranking.team.name} is already last."
    end
  end

  private

  def load_sport
    @sport = Sport.find_by!(key: params[:sport_slug])
  end

  def swap_ranks(a, b)
    UserTeamRanking.transaction do
      UserTeamRanking.connection.execute("SET CONSTRAINTS ALL DEFERRED")
      a_rank = a.rank
      a.update_columns(rank: b.rank)
      b.update_columns(rank: a_rank)
    end
  end
end
