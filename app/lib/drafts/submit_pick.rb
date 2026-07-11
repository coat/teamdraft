# frozen_string_literal: true

module Drafts
  # Records a single draft pick: validates ordering, increments the league
  # season clock, and transitions status. Raises if invalid.
  class SubmitPick
    Result = Data.define(:pick, :league_season)

    # Raised when the draft advanced between the caller reading
    # current_pick_number and this transaction acquiring the row lock (a
    # double-submit, or an auto-pick racing a human). Without the guard the
    # late arrival would be recorded as the *next* participant's pick.
    # Subclasses RecordInvalid so existing rescue paths handle it.
    class StalePick < ActiveRecord::RecordInvalid; end

    def self.call(...) = new(...).call

    # expected_pick_number is the pick the caller believes it is submitting
    # (from the rendered form or the clock job's key). nil skips the check -
    # only safe for sequential callers like test setup.
    def initialize(league_season:, season_team:, autopicked: false, expected_pick_number: nil)
      @league_season = league_season
      @season_team = season_team
      @autopicked = autopicked
      @expected_pick_number = expected_pick_number
    end

    def call
      ApplicationRecord.transaction do
        ls = LeagueSeason.lock.find(@league_season.id)
        guard_drafting_state!(ls)

        position = Order.position_for(
          pick_number: ls.current_pick_number,
          size: ls.size,
          style: ls.draft_order_style
        )
        participant = ls.participants.find_by!(draft_position: position)

        pick = ls.draft_picks.create!(
          participant:,
          season_team: @season_team,
          pick_number: ls.current_pick_number,
          autopicked: @autopicked
        )

        next_status =
          if pick.pick_number >= ls.total_picks
            "in_season"
          else
            "drafting"
          end

        ls.update!(
          current_pick_number: ls.current_pick_number + 1,
          status: next_status,
          draft_started_at: ls.draft_started_at || Time.current,
          draft_completed_at: (next_status == "in_season") ? Time.current : nil
        )

        schedule_next_clock(ls)

        Result.new(pick:, league_season: ls)
      end
    end

    private

    def schedule_next_clock(ls)
      return unless ls.live_mode?
      return unless ls.pick_clock_seconds.present?
      return unless ls.status == "drafting"

      Drafts::PickClockJob
        .set(wait: ls.pick_clock_seconds.seconds)
        .perform_later(ls.id, ls.current_pick_number)
    end

    def guard_drafting_state!(ls)
      if ls.status != "drafting"
        ls.errors.add(:base, "draft is not in progress")
        raise ActiveRecord::RecordInvalid.new(ls)
      end
      if ls.current_pick_number > ls.total_picks
        ls.errors.add(:base, "draft is complete")
        raise ActiveRecord::RecordInvalid.new(ls)
      end
      if @expected_pick_number && ls.current_pick_number != @expected_pick_number
        ls.errors.add(:base, "another pick was just made - check the board and try again")
        raise StalePick.new(ls)
      end
    end
  end
end
