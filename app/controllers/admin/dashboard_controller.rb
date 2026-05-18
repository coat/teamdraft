# frozen_string_literal: true

class Admin::DashboardController < Admin::BaseController
  def show
    render Views::Admin::Dashboard::Show.new(stats: gather_stats)
  end

  private

  def gather_stats
    week_ago = 7.days.ago
    {
      active_seasons: Season.where(status: "active").to_a,
      leagues: League.count,
      drafting_leagues: LeagueSeason.where(status: "drafting").count,
      games: Game.count,
      games_final: Game.final.count,
      scoring_events: ScoringEvent.count,
      users: User.count,
      admins: User.where(admin: true).count,
      disabled_users: User.where.not(disabled_at: nil).count,
      recent_leagues: League.where("created_at > ?", week_ago).order(created_at: :desc).limit(5).to_a,
      recent_users: User.where("created_at > ?", week_ago).order(created_at: :desc).limit(5).to_a
    }
  end
end
