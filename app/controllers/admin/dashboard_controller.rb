# frozen_string_literal: true

class Admin::DashboardController < Admin::BaseController
  def show
    render Views::Admin::Dashboard::Show.new(stats: gather_stats)
  end

  private

  def gather_stats
    {
      active_seasons: Season.where(status: "active").to_a,
      leagues: League.count,
      drafting_leagues: LeagueSeason.where(status: "drafting").count,
      games: Game.count,
      games_final: Game.final.count,
      scoring_events: ScoringEvent.count,
      users: User.count
    }
  end
end
