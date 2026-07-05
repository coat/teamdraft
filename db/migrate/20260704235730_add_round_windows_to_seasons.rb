class AddRoundWindowsToSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :round_windows, :jsonb, default: {}, null: false
  end
end
