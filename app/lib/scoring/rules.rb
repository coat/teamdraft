# frozen_string_literal: true

module Scoring
  # Per-sport scoring rules. Reads point values from sport.scoring_rules
  # (jsonb), with defaults baked in here for safety. Pure value object.
  #
  # NFL default — appearance-based, stacks each round you reach:
  #   1 point per regular-season win
  #   5 for making the playoffs
  #   5 more for making the divisional round
  #   10 more for making the conference championship
  #   10 more for making the Super Bowl
  #   5 more for winning the Super Bowl
  class Rules
    DEFAULTS = {
      "nfl" => {
        "regular_win" => 1,
        "playoff_appearance" => 5,
        "divisional_appearance" => 5,
        "conference_appearance" => 10,
        "championship_appearance" => 10,
        "championship_win" => 5
      }
    }.freeze

    def self.for(sport)
      new(sport)
    end

    def initialize(sport)
      @sport = sport
      @rules = (DEFAULTS[sport.key] || {}).merge(sport.scoring_rules || {})
    end

    def points_for(event_type)
      Integer(@rules.fetch(event_type, 0))
    end

    # Appearance event type awarded to each participant of a playoff game
    # of the given round. Regular-season wins and championship_win are
    # handled separately by Recompute.
    def appearance_event_for_round(round)
      case round
      when "wildcard" then "playoff_appearance"
      when "divisional" then "divisional_appearance"
      when "conference" then "conference_appearance"
      when "championship" then "championship_appearance"
      end
    end
  end
end
