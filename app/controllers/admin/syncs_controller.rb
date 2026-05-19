# frozen_string_literal: true

class Admin::SyncsController < Admin::BaseController
  def create
    season = Season.find(params[:season_id])
    back = redirect_target
    case params[:kind]
    when "games"
      if params[:dates_from].present? || params[:dates_to].present?
        return enqueue_date_range_sync(season, back)
      end
      round = params[:round].presence
      sport_key = season.sport.key
      if round && !SportsData::TheSportsDbProvider.round_numbers_for(sport_key).include?(round)
        return redirect_to back, alert: "Unknown round: #{round}"
      end
      Sync::GamesJob.perform_later(season.id, rounds: round && [round])
      label = round ? SportsData::TheSportsDbProvider.round_labels_for(sport_key).fetch(round) : "all rounds"
      redirect_to back, notice: "Games sync queued for #{season.label} (#{label})."
    when "scoring"
      Scoring::RecomputeJob.perform_later(season.id)
      redirect_to back, notice: "Scoring recompute queued for #{season.label}."
    else
      redirect_to back, alert: "Unknown sync kind: #{params[:kind]}"
    end
  end

  private

  MAX_SYNC_RANGE_DAYS = 60

  def enqueue_date_range_sync(season, back)
    from = Date.iso8601(params[:dates_from].to_s)
    to = Date.iso8601(params[:dates_to].to_s)
    if to < from
      return redirect_to back, alert: "End date must be on or after start date."
    end
    if (to - from).to_i + 1 > MAX_SYNC_RANGE_DAYS
      return redirect_to back, alert: "Date range too large (max #{MAX_SYNC_RANGE_DAYS} days)."
    end
    dates = (from..to).map(&:iso8601)
    Sync::GamesJob.perform_later(season.id, dates: dates)
    redirect_to back, notice: "Games sync queued for #{season.label} (#{from.iso8601} → #{to.iso8601}, #{dates.size} day(s))."
  rescue Date::Error
    redirect_to back, alert: "Invalid date(s) supplied."
  end

  # Whitelisted post-sync redirect target. Only /admin paths are accepted
  # so a stale `redirect_to` query param can't bounce users elsewhere.
  def redirect_target
    candidate = params[:redirect_to].to_s
    candidate.start_with?("/admin") ? candidate : admin_root_path
  end
end
