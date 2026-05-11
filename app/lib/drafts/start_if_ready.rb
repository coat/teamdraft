# frozen_string_literal: true

module Drafts
  # Transitions a draft from draft_pending → drafting when it's ready to go.
  #
  # Live drafts wait for both seats to be claimed and (optionally) for a
  # scheduled start time. Manual drafts — where the owner records both
  # players' picks — don't need either, since picks can be entered solo
  # offline. They start as soon as the league is created.
  #
  # Idempotent — safe to call from create, claim, and scheduled-job paths.
  class StartIfReady
    def self.call(...) = new(...).call

    def initialize(league:)
      @league = league
    end

    def call
      return unless @league.status == "draft_pending"
      return unless ready?

      if scheduled_in_future?
        schedule_start_job
        return
      end

      @league.update!(status: "drafting", draft_started_at: Time.current)
      schedule_first_clock
    end

    private

    def ready?
      manual? ? owner_joined? : seats_filled?
    end

    def manual? = @league.draft_mode == "manual"

    def owner_joined?
      @league.participants.where(is_owner: true).where.not(joined_at: nil).exists?
    end

    def seats_filled?
      @league.participants.where(joined_at: nil).none? &&
        @league.participants.count >= @league.size
    end

    # Scheduling only applies to live drafts — manual has no clock.
    def scheduled_in_future?
      !manual? &&
        @league.draft_scheduled_at.present? &&
        @league.draft_scheduled_at > Time.current
    end

    def schedule_start_job
      Drafts::StartDraftJob
        .set(wait_until: @league.draft_scheduled_at)
        .perform_later(@league.id)
    end

    def schedule_first_clock
      return unless @league.draft_mode == "live" && @league.pick_clock_seconds.present?
      Drafts::PickClockJob
        .set(wait: @league.pick_clock_seconds.seconds)
        .perform_later(@league.id, @league.current_pick_number)
    end
  end
end
