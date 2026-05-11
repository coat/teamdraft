# frozen_string_literal: true

class CreateSeasonTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :season_teams do |t|
      t.references :season, null: false, foreign_key: {on_delete: :cascade}
      t.references :team, null: false, foreign_key: {on_delete: :restrict}
      t.timestamps
    end

    add_index :season_teams, [:season_id, :team_id], unique: true
  end
end
