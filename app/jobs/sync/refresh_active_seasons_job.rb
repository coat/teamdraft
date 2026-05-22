# frozen_string_literal: true

# Every-10-minute live-score refresh. Wired into config/recurring.yml under
# the production environment; solid_queue runs it in-process via Puma. For
# each active season, enqueues a Sync::GamesJob targeting yesterday + today
# (UTC), which catches late-finishing games that crossed midnight on the
# previous tick. Idempotent end-to-end: Sync::ApplyGames upserts by
# (season_id, external_id), so overlapping ticks are safe.
#
# Seasons without an external_id are skipped - the provider would no-op
# anyway, and logging the skip keeps the recurring tick's output tidy.

module Sync
  class RefreshActiveSeasonsJob < ApplicationJob
    queue_as :default

    def perform
      seasons = Season.active.includes(:sport)
      dates = [Date.yesterday, Date.current]
      enqueued = skipped = 0
      seasons.find_each do |season|
        if season.external_id.blank?
          Rails.logger.info("[sync:refresh] skip season=#{season.id} sport=#{season.sport.key} (no external_id)")
          skipped += 1
          next
        end
        Sync::GamesJob.perform_later(season.id, dates: dates.map(&:iso8601))
        enqueued += 1
      end
      Rails.logger.info("[sync:refresh] dates=#{dates.map(&:iso8601).join(",")} enqueued=#{enqueued} skipped=#{skipped}")
    end
  end
end
