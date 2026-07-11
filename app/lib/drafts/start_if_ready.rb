# frozen_string_literal: true

module Drafts
  # Transitions a draft from draft_pending -> drafting when it's ready to go.
  #
  # Live drafts wait for both seats to be claimed and (optionally) for a
  # scheduled start time. Manual drafts - where the owner records both
  # players' picks - don't need either, since picks can be entered solo
  # offline. They start as soon as the league season is created.
  #
  # Idempotent - safe to call from create, claim, and scheduled-job paths.
  class StartIfReady
    def self.call(...) = new(...).call

    def initialize(league_season:)
      @league_season = league_season
    end

    def call
      return unless @league_season.status == "draft_pending"
      return unless ready?

      if scheduled_in_future?
        schedule_start_job
        return
      end

      @league_season.update!(status: "drafting", draft_started_at: Time.current)
      schedule_first_clock
    end

    private

    def ready?
      @league_season.manual_mode? ? owner_joined? : seats_filled?
    end

    def owner_joined?
      @league_season.participants.where(is_owner: true).where.not(joined_at: nil).exists?
    end

    def seats_filled?
      @league_season.participants.where(joined_at: nil).none? &&
        @league_season.participants.count >= @league_season.size
    end

    def scheduled_in_future?
      @league_season.live_mode? &&
        @league_season.draft_scheduled_at.present? &&
        @league_season.draft_scheduled_at > Time.current
    end

    def schedule_start_job
      Drafts::StartDraftJob
        .set(wait_until: @league_season.draft_scheduled_at)
        .perform_later(@league_season.id)
    end

    def schedule_first_clock
      return unless @league_season.live_mode? && @league_season.pick_clock_seconds.present?
      Drafts::PickClockJob
        .set(wait: @league_season.pick_clock_seconds.seconds)
        .perform_later(@league_season.id, @league_season.current_pick_number)
    end
  end
end
