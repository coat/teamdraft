# frozen_string_literal: true

# Point values now live on LeagueSeasonScoringRule and are resolved at standings
# read time via Scoring::Rules.for_league_season. ScoringEvent only records that
# an event happened; the cached points column had become dead weight (and a
# source of confusion now that the same event can be worth different points in
# different leagues).
class DropPointsFromScoringEvents < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :scoring_events, name: "scoring_events_points_non_negative"
    remove_column :scoring_events, :points
  end

  def down
    add_column :scoring_events, :points, :integer, null: false, default: 0
    add_check_constraint :scoring_events, "points >= 0",
      name: "scoring_events_points_non_negative"
  end
end
