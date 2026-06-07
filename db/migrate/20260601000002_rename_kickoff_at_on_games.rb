# frozen_string_literal: true

class RenameKickoffAtOnGames < ActiveRecord::Migration[8.1]
  def change
    # rename_column on Postgres auto-renames conventional column indexes,
    # so index_games_on_kickoff_at becomes index_games_on_starts_at without
    # an explicit rename_index call.
    rename_column :games, :kickoff_at, :starts_at
  end
end
