# frozen_string_literal: true

class AddLastSyncedAtToSeasons < ActiveRecord::Migration[8.1]
  def change
    add_column :seasons, :last_synced_at, :datetime
  end
end
