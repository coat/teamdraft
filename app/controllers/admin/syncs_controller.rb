# frozen_string_literal: true

class Admin::SyncsController < Admin::BaseController
  def create
    season = Season.find(params[:season_id])
    back = redirect_target
    case params[:kind]
    when "games"
      round = params[:round].presence
      if round && !SportsData::TheSportsDbProvider::ROUND_NUMBERS.include?(round)
        return redirect_to back, alert: "Unknown round: #{round}"
      end
      Sync::GamesJob.perform_later(season.id, rounds: round && [round])
      label = round ? SportsData::TheSportsDbProvider::ROUND_LABELS.fetch(round) : "all rounds"
      redirect_to back, notice: "Games sync queued for #{season.label} (#{label})."
    when "scoring"
      Scoring::RecomputeJob.perform_later(season.id)
      redirect_to back, notice: "Scoring recompute queued for #{season.label}."
    else
      redirect_to back, alert: "Unknown sync kind: #{params[:kind]}"
    end
  end

  private

  # Whitelisted post-sync redirect target. Only /admin paths are accepted
  # so a stale `redirect_to` query param can't bounce users elsewhere.
  def redirect_target
    candidate = params[:redirect_to].to_s
    candidate.start_with?("/admin") ? candidate : admin_root_path
  end
end
