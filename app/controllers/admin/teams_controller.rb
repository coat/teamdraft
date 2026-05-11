# frozen_string_literal: true

class Admin::TeamsController < Admin::BaseController
  before_action :load_team, only: [:edit, :update]

  def index
    teams = Team.includes(:sport).order(:sport_id, :default_pick_rank, :name)
    render Views::Admin::Teams::Index.new(teams: teams)
  end

  def edit
    render Views::Admin::Teams::Edit.new(team: @team)
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

  def team_params
    params.require(:team).permit(:name, :abbreviation, :external_id, :default_pick_rank, :conference, :division, :primary_color, :logo_url)
  end
end
