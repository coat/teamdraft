# frozen_string_literal: true

# Move per-sport scoring config from sports.scoring_rules (jsonb) into a
# normalized scoring_rules table, and relax NFL-specific check constraints on
# games.round and scoring_events.event_type so other sports (NBA, etc.) can
# define their own playoff stages without further migrations.
class IntroduceScoringRulesTable < ActiveRecord::Migration[8.1]
  def up
    create_table :scoring_rules do |t|
      t.references :sport, null: false, foreign_key: {on_delete: :cascade}
      t.string :event_type, null: false
      t.string :kind, null: false
      t.string :round_key
      t.integer :points, null: false, default: 0
      t.string :label, null: false
      t.string :short_label, null: false
      t.integer :display_order, null: false, default: 0
      t.boolean :bye_backfill, null: false, default: false
      t.timestamps
    end

    add_index :scoring_rules, [:sport_id, :event_type], unique: true,
      name: "index_scoring_rules_unique_event_per_sport"
    add_index :scoring_rules, [:sport_id, :round_key], unique: true,
      where: "round_key IS NOT NULL",
      name: "index_scoring_rules_unique_round_per_sport"

    add_check_constraint :scoring_rules,
      "kind IN ('regular_win','playoff_appearance','championship_win')",
      name: "scoring_rules_kind_valid"
    add_check_constraint :scoring_rules,
      "points >= 0",
      name: "scoring_rules_points_non_negative"

    add_column :sports, :about_blurb, :text

    backfill_existing_sports

    remove_column :sports, :scoring_rules

    remove_check_constraint :games, name: "games_round_valid"
    remove_check_constraint :scoring_events, name: "scoring_events_event_type_valid"
  end

  def down
    add_column :sports, :scoring_rules, :jsonb, null: false, default: {}
    remove_column :sports, :about_blurb
    drop_table :scoring_rules

    add_check_constraint :games,
      "round IN ('regular_season','wildcard','divisional','conference','championship')",
      name: "games_round_valid"
    add_check_constraint :scoring_events,
      "event_type IN ('regular_win','playoff_appearance','divisional_appearance','conference_appearance','championship_appearance','championship_win')",
      name: "scoring_events_event_type_valid"
  end

  private

  # Each sport that already had a scoring_rules jsonb keeps its point values.
  # The kind/round_key/label/display_order metadata is supplied here for the
  # known NFL shape; new sports will be inserted via seeds.
  def backfill_existing_sports
    nfl_template = [
      {event_type: "regular_win", kind: "regular_win", round_key: nil, label: "Regular-season win", short_label: "Regular Season", display_order: 0},
      {event_type: "playoff_appearance", kind: "playoff_appearance", round_key: "wildcard", label: "Made the playoffs", short_label: "Wild Card", display_order: 1, bye_backfill: true},
      {event_type: "divisional_appearance", kind: "playoff_appearance", round_key: "divisional", label: "Made the divisional round", short_label: "Divisional", display_order: 2},
      {event_type: "conference_appearance", kind: "playoff_appearance", round_key: "conference", label: "Made the conference championship", short_label: "Conference", display_order: 3},
      {event_type: "championship_appearance", kind: "playoff_appearance", round_key: "championship", label: "Made the Super Bowl", short_label: "Super Bowl", display_order: 4},
      {event_type: "championship_win", kind: "championship_win", round_key: nil, label: "Won the Super Bowl", short_label: "Champion", display_order: 5}
    ]

    sport = Class.new(ActiveRecord::Base) { self.table_name = "sports" }
    rule = Class.new(ActiveRecord::Base) { self.table_name = "scoring_rules" }

    sport.where(key: "nfl").find_each do |s|
      jsonb = s.scoring_rules || {}
      nfl_template.each do |row|
        rule.create!(
          sport_id: s.id,
          event_type: row[:event_type],
          kind: row[:kind],
          round_key: row[:round_key],
          points: Integer(jsonb[row[:event_type]] || 0),
          label: row[:label],
          short_label: row[:short_label],
          display_order: row[:display_order],
          bye_backfill: row[:bye_backfill] || false
        )
      end
    end
  end
end
