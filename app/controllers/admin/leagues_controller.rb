# frozen_string_literal: true

class Admin::LeaguesController < Admin::BaseController
  before_action :load_league, only: [:edit, :update, :destroy]

  def index
    leagues = League.includes(league_seasons: [:season, participants: :user])
      .order("leagues.name")
    render Views::Admin::Leagues::Index.new(leagues: leagues)
  end

  def edit
    render Views::Admin::Leagues::Edit.new(league: @league, league_season: @league.current_league_season)
  end

  def update
    league_season = @league.current_league_season
    ApplicationRecord.transaction do
      @league.update!(league_params)
      league_season&.update!(league_season_params) if params[:league_season].present?
    end
    redirect_to admin_leagues_path, notice: "Updated #{@league.name}."
  rescue ActiveRecord::RecordInvalid
    render Views::Admin::Leagues::Edit.new(league: @league, league_season: league_season), status: :unprocessable_entity
  end

  def destroy
    name = @league.name
    @league.destroy!
    redirect_to admin_leagues_path, notice: "Deleted #{name}."
  end

  private

  def load_league
    @league = League.includes(league_seasons: [participants: :user]).friendly.find(params[:id])
  end

  def league_params
    params.require(:league).permit(:name)
  end

  def league_season_params
    params.require(:league_season).permit(
      :size, :draft_mode, :draft_order_style,
      :status, :pick_clock_seconds, :current_pick_number
    )
  end
end
