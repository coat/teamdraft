# frozen_string_literal: true

class Admin::TeamsController < Admin::BaseController
  before_action :load_team, only: [:edit, :update, :move_up, :move_down]

  def index
    query = Admin::Teams::ListQuery.new(params)
    pagy, teams = pagy(query.relation)
    sports = Sport.order(:key).pluck(:name, :id)
    top_ids, bottom_ids = rank_markers(query)

    render Views::Admin::Teams::Index.new(
      query: query, teams: teams, sports: sports,
      top_ids: top_ids, bottom_ids: bottom_ids, pagy: pagy
    )
  end

  def edit
    render Views::Admin::Teams::Edit.new(team: @team)
  end

  def move_up
    if @team.default_pick_rank.nil?
      return redirect_to admin_teams_path(list_params), alert: "Cannot move a team without a pick rank."
    end

    swap_with = Team.where(sport_id: @team.sport_id)
      .where.not(id: @team.id)
      .where(default_pick_rank: ...@team.default_pick_rank)
      .order(default_pick_rank: :desc)
      .first

    if swap_with
      swap_ranks(@team, swap_with)
      redirect_to admin_teams_path(list_params), notice: "Moved #{@team.name} up."
    else
      redirect_to admin_teams_path(list_params), alert: "#{@team.name} is already at the top."
    end
  end

  def move_down
    if @team.default_pick_rank.nil?
      return redirect_to admin_teams_path(list_params), alert: "Cannot move a team without a pick rank."
    end

    swap_with = Team.where(sport_id: @team.sport_id)
      .where.not(id: @team.id)
      .where(default_pick_rank: (@team.default_pick_rank + 1)..)
      .order(default_pick_rank: :asc)
      .first

    if swap_with
      swap_ranks(@team, swap_with)
      redirect_to admin_teams_path(list_params), notice: "Moved #{@team.name} down."
    else
      redirect_to admin_teams_path(list_params), alert: "#{@team.name} is already at the bottom."
    end
  end

  def update
    if @team.update(team_params)
      redirect_to admin_teams_path(list_params), notice: "Updated #{@team.name}."
    else
      render Views::Admin::Teams::Edit.new(team: @team), status: :unprocessable_entity
    end
  end

  private

  # Compute "top of rank" / "bottom of rank" per sport from the full filtered
  # set, not just the current page, so the arrow-disable badges stay correct
  # when pagination is in play.
  def rank_markers(query)
    ranked = query.relation
      .unscope(:limit, :offset, :order)
      .where.not(default_pick_rank: nil)
      .pluck(:id, :sport_id, :default_pick_rank)

    top = Set.new
    bottom = Set.new
    ranked.group_by { |_id, sport_id, _rank| sport_id }.each_value do |rows|
      top.add(rows.min_by { |_id, _sport_id, rank| rank }[0])
      bottom.add(rows.max_by { |_id, _sport_id, rank| rank }[0])
    end
    [top, bottom]
  end

  def list_params
    params.permit(:q, :sport_id, :sort, :dir, :page).to_h.compact_blank
  end

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
