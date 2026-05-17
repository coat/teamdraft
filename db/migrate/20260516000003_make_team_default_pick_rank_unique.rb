# frozen_string_literal: true

class MakeTeamDefaultPickRankUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :teams, name: "index_teams_on_sport_id_and_default_pick_rank"
    add_index :teams, [:sport_id, :default_pick_rank],
      unique: true,
      name: "index_teams_on_sport_id_and_default_pick_rank"
  end
end
