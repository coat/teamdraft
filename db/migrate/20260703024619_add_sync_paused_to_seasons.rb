class AddSyncPausedToSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :sync_paused, :boolean, default: false, null: false
  end
end
