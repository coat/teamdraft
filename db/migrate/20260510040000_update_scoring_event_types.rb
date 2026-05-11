# frozen_string_literal: true

# Swap the scoring_events.event_type check constraint to the appearance-based
# scheme (matches the Mina Kimes draft rules: 5 for making each playoff round,
# stacking, plus 5 for winning the Super Bowl).
class UpdateScoringEventTypes < ActiveRecord::Migration[8.1]
  OLD = %w[regular_win wildcard_win divisional_win conference_win championship_appearance championship_win]
  NEW = %w[regular_win playoff_appearance divisional_appearance conference_appearance championship_appearance championship_win]

  def up
    # No reference data exists for the deprecated win-based types in any
    # deployment yet; drop any stragglers from dev/test databases so the
    # tightened constraint can be applied.
    execute "DELETE FROM scoring_events WHERE event_type IN ('wildcard_win','divisional_win','conference_win')"
    remove_check_constraint :scoring_events, name: "scoring_events_event_type_valid"
    add_check_constraint :scoring_events,
      "event_type IN (#{NEW.map { |t| "'#{t}'" }.join(",")})",
      name: "scoring_events_event_type_valid"
  end

  def down
    remove_check_constraint :scoring_events, name: "scoring_events_event_type_valid"
    add_check_constraint :scoring_events,
      "event_type IN (#{OLD.map { |t| "'#{t}'" }.join(",")})",
      name: "scoring_events_event_type_valid"
  end
end
