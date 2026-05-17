# frozen_string_literal: true

class Admin::TeamsController < Admin::BaseController
  before_action :load_team, only: [:edit, :update, :move_up, :move_down]

  def index
    query = Admin::Teams::ListQuery.new(params)
    teams = query.relation.to_a
    sports = Sport.order(:key).pluck(:name, :id)

    top_ids = Set.new
    bottom_ids = Set.new
    teams.group_by(&:sport_id).each_value do |sport_teams|
      ranked = sport_teams.select(&:default_pick_rank)
      next if ranked.empty?

      top_ids.add(ranked.min_by(&:default_pick_rank).id)
      bottom_ids.add(ranked.max_by(&:default_pick_rank).id)
    end

    render Views::Admin::Teams::Index.new(
      query: query, teams: teams, sports: sports,
      top_ids: top_ids, bottom_ids: bottom_ids
    )
  end

  def edit
    render Views::Admin::Teams::Edit.new(team: @team)
  end

  def move_up
    if @team.default_pick_rank.nil?
      return redirect_to admin_teams_path, alert: "Cannot move a team without a pick rank."
    end

    swap_with = Team.where(sport_id: @team.sport_id)
      .where.not(id: @team.id)
      .where(default_pick_rank: ...@team.default_pick_rank)
      .order(default_pick_rank: :desc)
      .first

    if swap_with
      swap_ranks(@team, swap_with)
      redirect_to admin_teams_path, notice: "Moved #{@team.name} up."
    else
      redirect_to admin_teams_path, alert: "#{@team.name} is already at the top."
    end
  end

  def move_down
    if @team.default_pick_rank.nil?
      return redirect_to admin_teams_path, alert: "Cannot move a team without a pick rank."
    end

    swap_with = Team.where(sport_id: @team.sport_id)
      .where.not(id: @team.id)
      .where(default_pick_rank: (@team.default_pick_rank + 1)..)
      .order(default_pick_rank: :asc)
      .first

    if swap_with
      swap_ranks(@team, swap_with)
      redirect_to admin_teams_path, notice: "Moved #{@team.name} down."
    else
      redirect_to admin_teams_path, alert: "#{@team.name} is already at the bottom."
    end
  end

  def update
    if @team.update(team_params)
      redirect_to admin_teams_path, notice: "Updated #{@team.name}."
    else
      render Views::Admin::Teams::Edit.new(team: @team), status: :unprocessable_entity
    end
  end

  private

  def load_team
    @team = Team.find(params[:id])
  end

  def swap_ranks(a, b)
    Team.transaction do
      a_rank = a.default_pick_rank
      b_rank = b.default_pick_rank
      a.update!(default_pick_rank: nil)
      b.update!(default_pick_rank: a_rank)
      a.update!(default_pick_rank: b_rank)
    end
  end

  def team_params
    params.require(:team).permit(:name, :abbreviation, :external_id, :default_pick_rank, :conference, :division, :primary_color, :logo_url)
  end
end
