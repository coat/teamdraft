# frozen_string_literal: true

# Makes the (league_season_id, draft_position) uniqueness deferrable so an
# owner-initiated swap can write both new values within a single transaction
# without tripping the per-row check.
class DeferParticipantDraftPositionUniqueness < ActiveRecord::Migration[8.1]
  def up
    remove_index :participants,
      name: "index_participants_on_league_season_id_and_draft_position"
    execute <<~SQL
      ALTER TABLE participants
      ADD CONSTRAINT participants_league_season_id_draft_position_unique
      UNIQUE (league_season_id, draft_position)
      DEFERRABLE INITIALLY IMMEDIATE
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE participants
      DROP CONSTRAINT participants_league_season_id_draft_position_unique
    SQL
    add_index :participants, [:league_season_id, :draft_position],
      unique: true,
      name: "index_participants_on_league_season_id_and_draft_position"
  end
end
