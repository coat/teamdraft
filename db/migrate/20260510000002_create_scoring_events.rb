# frozen_string_literal: true

class CreateScoringEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :scoring_events do |t|
      t.references :season_team, null: false, foreign_key: {on_delete: :cascade}
      t.references :game, foreign_key: {on_delete: :cascade}
      t.string :event_type, null: false
      t.integer :points, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :scoring_events, [:season_team_id, :game_id, :event_type],
      unique: true,
      name: "index_scoring_events_unique_per_team_game_type"
    add_index :scoring_events, [:season_team_id, :occurred_at]

    add_check_constraint :scoring_events,
      "event_type IN ('regular_win','wildcard_win','divisional_win','conference_win','championship_appearance','championship_win')",
      name: "scoring_events_event_type_valid"
    add_check_constraint :scoring_events,
      "points >= 0",
      name: "scoring_events_points_non_negative"
  end
end
