# frozen_string_literal: true

# Per-user personal team rankings. When set, these override
# teams.default_pick_rank during AutoPick for that user's seats.
# Partial rankings are allowed: unranked teams fall back to the
# global ordering. Sport is denormalized from team.sport_id so the
# (user_id, sport_id) rank-uniqueness is expressible as one index
# and AutoPick can join in a single hop.
class CreateUserTeamRankings < ActiveRecord::Migration[8.1]
  def up
    create_table :user_team_rankings do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}
      t.references :team, null: false, foreign_key: {on_delete: :cascade}
      t.references :sport, null: false, foreign_key: {on_delete: :cascade}
      t.integer :rank, null: false
      t.timestamps
    end

    add_index :user_team_rankings, [:user_id, :team_id], unique: true
    add_index :user_team_rankings, [:user_id, :sport_id]

    execute <<~SQL
      ALTER TABLE user_team_rankings
      ADD CONSTRAINT user_team_rankings_user_sport_rank_unique
      UNIQUE (user_id, sport_id, rank)
      DEFERRABLE INITIALLY IMMEDIATE
    SQL

    add_check_constraint :user_team_rankings,
      "rank > 0",
      name: "user_team_rankings_rank_positive"
  end

  def down
    drop_table :user_team_rankings
  end
end
