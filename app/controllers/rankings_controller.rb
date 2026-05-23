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
    view = Views::Rankings::Index.new(
      sport: @sport, ranked: ranked, unranked: unranked,
      frame: turbo_frame_request?
    )
    if turbo_frame_request?
      render view, layout: false
    else
      render view
    end
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
    ranking.destroy!
    redirect_to sport_rankings_path(@sport.key), notice: "Removed #{ranking.team.name}."
  end

  def move_up
    move(:up, edge: "first")
  end

  def move_down
    move(:down, edge: "last")
  end

  private

  def move(direction, edge:)
    ranking = current_user.team_rankings.find(params[:id])
    moved = (direction == :up) ? ranking.move_up! : ranking.move_down!
    if moved
      redirect_to sport_rankings_path(@sport.key),
        notice: "Moved #{ranking.team.name} #{direction}."
    else
      redirect_to sport_rankings_path(@sport.key),
        alert: "#{ranking.team.name} is already #{edge}."
    end
  end

  def load_sport
    @sport = Sport.find_by!(key: params[:sport_slug])
  end
end
