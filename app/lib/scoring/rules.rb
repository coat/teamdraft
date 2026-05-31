# frozen_string_literal: true

module Scoring
  # Per-sport scoring rules, loaded from the scoring_rules table. One row per
  # earnable event_type. The rule's `kind` (regular_win | playoff_appearance |
  # championship_win) tells Recompute how to award it, and `round_key` links a
  # playoff-appearance rule to the matching games.round value for that sport.
  #
  # Two factories:
  #   - .for(sport) reads point values straight from ScoringRule rows; used by
  #     Scoring::Recompute, which is sport-wide and ignorant of leagues.
  #   - .for_league_season(league_season) overlays the league's per-rule point
  #     overrides; used by Standings::Calculate at read time so owners can tune
  #     point values mid-season without re-running Recompute.
  class Rules
    UnknownEvent = Class.new(StandardError)

    def self.for(sport)
      new(sport)
    end

    def self.for_league_season(league_season)
      overrides = league_season.scoring_rule_overrides.includes(:scoring_rule).to_a
      points_by_event = overrides.to_h { |o| [o.scoring_rule.event_type, Integer(o.points)] }
      new(league_season.season.sport, points_override: points_by_event)
    end

    def initialize(sport, points_override: nil)
      @sport = sport
      @rules = sport.scoring_rules.ordered.to_a
      @points_override = points_override
    end

    # The sport's ScoringRule records in canonical display order. Used by
    # views that want to render a per-event breakdown with human-readable
    # labels - point values are still resolved through `points_for` so
    # league-specific overrides win.
    def ordered_rules
      @rules
    end

    def points_for(event_type)
      return Integer(@points_override[event_type] || 0) if @points_override
      rule = by_event_type[event_type]
      rule ? Integer(rule.points) : 0
    end

    # Appearance event_type awarded to each participant of a playoff game of
    # the given round, or nil if the sport doesn't score that round.
    def appearance_event_for_round(round)
      by_round_key[round]&.event_type
    end

    def regular_win_event
      @regular_win_event ||= @rules.find { |r| r.kind == "regular_win" }&.event_type
    end

    def championship_win_event
      @championship_win_event ||= @rules.find { |r| r.kind == "championship_win" }&.event_type
    end

    # The rule (if any) flagged as bye-backfillable: a team that participates
    # in the round *after* this one without having a prior appearance event
    # for this rule retroactively gets credit. Used for NFL playoff byes.
    def bye_backfill_rule
      @bye_backfill_rule ||= @rules.find(&:bye_backfill)
    end

    # The round_key whose game triggers the bye backfill - i.e. the round
    # immediately after the bye-backfill rule in display_order.
    def bye_backfill_trigger_round
      return nil unless bye_backfill_rule
      idx = @rules.index(bye_backfill_rule)
      @rules[idx + 1]&.round_key
    end

    private

    def by_event_type
      @by_event_type ||= @rules.index_by(&:event_type)
    end

    def by_round_key
      @by_round_key ||= @rules.reject { |r| r.round_key.nil? }.index_by(&:round_key)
    end
  end
end
