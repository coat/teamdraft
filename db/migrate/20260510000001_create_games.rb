# frozen_string_literal: true

class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :season, null: false, foreign_key: {on_delete: :cascade}
      t.string :external_id
      t.integer :week
      t.string :round, null: false, default: "regular_season"
      t.references :home_season_team, null: false,
        foreign_key: {to_table: :season_teams, on_delete: :restrict},
        index: true
      t.references :away_season_team, null: false,
        foreign_key: {to_table: :season_teams, on_delete: :restrict},
        index: true
      t.datetime :kickoff_at, null: false
      t.string :status, null: false, default: "scheduled"
      t.integer :home_score
      t.integer :away_score
      t.datetime :completed_at
      t.timestamps
    end

    add_index :games, [:season_id, :external_id],
      unique: true,
      where: "external_id IS NOT NULL",
      name: "index_games_on_season_and_external_id"
    add_index :games, :kickoff_at

    add_check_constraint :games,
      "round IN ('regular_season','wildcard','divisional','conference','championship')",
      name: "games_round_valid"
    add_check_constraint :games,
      "status IN ('scheduled','in_progress','final','postponed')",
      name: "games_status_valid"
    add_check_constraint :games,
      "home_season_team_id <> away_season_team_id",
      name: "games_distinct_teams"
    add_check_constraint :games,
      "(status <> 'final') OR (home_score IS NOT NULL AND away_score IS NOT NULL)",
      name: "games_final_has_scores"
  end
end
