# frozen_string_literal: true

class AddAutopickedToDraftPicks < ActiveRecord::Migration[8.0]
  def change
    add_column :draft_picks, :autopicked, :boolean, null: false, default: false
  end
end
