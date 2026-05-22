# frozen_string_literal: true

module Drafts
  # Auto-picks for the on-the-clock participant when their timer expires.
  # Scheduled (set: deadline) when a pick lands or the draft starts.
  #
  # Idempotency: the job is keyed by (league_season_id, expected_pick_number).
  # If the league season's current pick has already advanced past that number
  # - meaning the human picked in time - the job is a no-op. Multiple stale
  # jobs in flight collapse to zero work.
  class PickClockJob < ApplicationJob
    queue_as :default

    def perform(league_season_id, expected_pick_number)
      ls = LeagueSeason.find(league_season_id)
      return unless ls.draft_mode == "live"
      return unless %w[draft_pending drafting].include?(ls.status)
      return unless ls.current_pick_number == expected_pick_number

      AutoPick.call(league_season: ls)
    end
  end
end
