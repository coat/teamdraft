# frozen_string_literal: true

class CreateDraftPicks < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_picks do |t|
      t.references :league, null: false, foreign_key: {on_delete: :cascade}
      t.references :participant, null: false, foreign_key: {on_delete: :restrict}
      t.references :season_team, null: false, foreign_key: {on_delete: :restrict}
      t.integer :pick_number, null: false
      t.datetime :picked_at, null: false
      t.timestamps
    end

    add_index :draft_picks, [:league_id, :pick_number], unique: true
    add_index :draft_picks, [:league_id, :season_team_id], unique: true

    add_check_constraint :draft_picks,
      "pick_number >= 1",
      name: "draft_picks_pick_number_positive"
  end
end
