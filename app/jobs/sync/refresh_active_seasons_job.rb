# frozen_string_literal: true

# Recurring live-score refresh (interval configured in config/recurring.yml).
# Wired into config/recurring.yml under the production environment; solid_queue
# runs it in-process via Puma. For
# each active season, decides whether the season is in a "play window" via
# Season#score_sync_reason and only then enqueues a Sync::GamesJob targeting
# yesterday + today (UTC). Yesterday is included to catch late-finishing
# games that crossed midnight on the previous tick. Idempotent end-to-end:
# Sync::ApplyGames upserts by (season_id, external_id), so overlapping ticks
# are safe.
#
# Seasons without an external_id or with sync_paused: true are skipped.
# Pausing a season stops the automated refresh without changing its status.

module Sync
  class RefreshActiveSeasonsJob < ApplicationJob
    queue_as :default

    def perform
      seasons = Season.active.includes(:sport)
      dates = [Date.yesterday, Date.current]
      reasons = Hash.new(0)
      seasons.find_each do |season|
        if season.external_id.blank?
          Rails.logger.info("[sync:refresh] skip season=#{season.id} sport=#{season.sport.key} (no external_id)")
          reasons[:no_external_id] += 1
          next
        end
        if season.sync_paused?
          reasons[:paused] += 1
          next
        end
        reason = season.score_sync_reason
        if reason.nil?
          reasons[:idle] += 1
          next
        end
        Sync::GamesJob.perform_later(season.id, dates: dates.map(&:iso8601))
        reasons[reason] += 1
      end
      Rails.logger.info("[sync:refresh] dates=#{dates.map(&:iso8601).join(",")} reasons=#{reasons.to_h}")
    end
  end
end
