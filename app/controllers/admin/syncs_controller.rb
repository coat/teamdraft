# frozen_string_literal: true

class Admin::SyncsController < Admin::BaseController
  def create
    season = Season.find(params[:season_id])
    case params[:kind]
    when "games"
      Sync::GamesJob.perform_later(season.id)
      redirect_to admin_root_path, notice: "Games sync queued for #{season.label}."
    when "scoring"
      Scoring::RecomputeJob.perform_later(season.id)
      redirect_to admin_root_path, notice: "Scoring recompute queued for #{season.label}."
    else
      redirect_to admin_root_path, alert: "Unknown sync kind: #{params[:kind]}"
    end
  end
end
