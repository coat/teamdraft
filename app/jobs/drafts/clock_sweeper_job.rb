# frozen_string_literal: true

module Drafts
  # Recurring safety net for live drafts. Re-enqueues PickClockJob for any
  # league season whose current pick's deadline has elapsed but hasn't
  # advanced - covering cases where the originally scheduled job was lost
  # (a worker crash, an unlucky deploy, an adapter switch).
  #
  # PickClockJob guards on (league_season_id, expected_pick_number), so a
  # re-enqueue is a no-op if a real job is still in flight or the human
  # picked in time.
  class ClockSweeperJob < ApplicationJob
    queue_as :default

    GRACE_SECONDS = 5

    def perform
      candidates = ActiveRecord::Base.logger.silence do
        LeagueSeason
          .where(status: "drafting", draft_mode: "live")
          .where.not(pick_clock_seconds: nil)
          .to_a
      end

      now = Time.current
      due = candidates.select do |ls|
        deadline = clock_deadline(ls)
        deadline.present? && now >= deadline + GRACE_SECONDS
      end

      due.each do |ls|
        Drafts::PickClockJob.perform_later(ls.id, ls.current_pick_number)
      end
    end

    private

    def clock_deadline(ls)
      base = ActiveRecord::Base.logger.silence { ls.draft_picks.maximum(:picked_at) } || ls.draft_started_at
      return nil if base.nil?
      base + ls.pick_clock_seconds.seconds
    end
  end
end
