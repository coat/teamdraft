# frozen_string_literal: true

class AddDefaultPickRankToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :default_pick_rank, :integer
    add_index :teams, [:sport_id, :default_pick_rank]
    add_check_constraint :teams,
      "default_pick_rank IS NULL OR default_pick_rank > 0",
      name: "teams_default_pick_rank_positive"
  end
end
