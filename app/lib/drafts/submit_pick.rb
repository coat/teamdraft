# frozen_string_literal: true

module Drafts
  # Records a single draft pick: validates ordering, increments the league
  # clock, and transitions league status. Raises if invalid.
  class SubmitPick
    Result = Data.define(:pick, :league)

    def self.call(...) = new(...).call

    def initialize(league:, season_team:)
      @league = league
      @season_team = season_team
    end

    def call
      ApplicationRecord.transaction do
        league = League.lock.find(@league.id)
        guard_drafting_state!(league)

        position = Order.position_for(
          pick_number: league.current_pick_number,
          size: league.size,
          style: league.draft_order_style
        )
        participant = league.participants.find_by!(draft_position: position)

        pick = league.draft_picks.create!(
          participant:,
          season_team: @season_team,
          pick_number: league.current_pick_number
        )

        next_status =
          if pick.pick_number >= league.total_picks
            "in_season"
          else
            "drafting"
          end

        league.update!(
          current_pick_number: league.current_pick_number + 1,
          status: next_status,
          draft_started_at: league.draft_started_at || Time.current,
          draft_completed_at: (next_status == "in_season") ? Time.current : nil
        )

        schedule_next_clock(league)

        Result.new(pick:, league:)
      end
    end

    private

    def schedule_next_clock(league)
      return unless league.draft_mode == "live"
      return unless league.pick_clock_seconds.present?
      return unless league.status == "drafting"

      Drafts::PickClockJob
        .set(wait: league.pick_clock_seconds.seconds)
        .perform_later(league.id, league.current_pick_number)
    end

    def guard_drafting_state!(league)
      if league.status != "drafting"
        league.errors.add(:base, "draft is not in progress")
        raise ActiveRecord::RecordInvalid.new(league)
      end
      if league.current_pick_number > league.total_picks
        league.errors.add(:base, "draft is complete")
        raise ActiveRecord::RecordInvalid.new(league)
      end
    end
  end
end
