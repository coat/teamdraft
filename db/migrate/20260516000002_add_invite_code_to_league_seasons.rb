# frozen_string_literal: true

class AddInviteCodeToLeagueSeasons < ActiveRecord::Migration[8.0]
  def up
    add_column :league_seasons, :invite_code, :string

    existing = connection.select_values("SELECT invite_code FROM league_seasons WHERE invite_code IS NOT NULL").to_set
    LeagueSeason.reset_column_information
    LeagueSeason.where(invite_code: nil).find_each do |ls|
      code = nil
      loop do
        candidate = Haikunator.haikunate(999)
        unless existing.include?(candidate)
          code = candidate
          existing << candidate
          break
        end
      end
      ls.update_columns(invite_code: code)
    end

    change_column_null :league_seasons, :invite_code, false
    add_index :league_seasons, :invite_code, unique: true
  end

  def down
    remove_index :league_seasons, :invite_code
    remove_column :league_seasons, :invite_code
  end
end
