# frozen_string_literal: true

class RenameLeagueIdOnParticipantsAndDraftPicks < ActiveRecord::Migration[8.0]
  def up
    # Backfill: each existing League gets a LeagueSeason carrying its
    # per-season state. We preserve `id` so the column rename below
    # (league_id → league_season_id) keeps participants' and draft_picks'
    # existing FK references valid. No-op on fresh installs.
    if column_exists?(:leagues, :season_id) && connection.select_value("SELECT COUNT(*) FROM league_seasons").to_i.zero?
      execute(<<~SQL)
        INSERT INTO league_seasons (id, league_id, season_id, status, size, draft_mode,
          draft_order_style, current_pick_number, pick_clock_seconds,
          draft_scheduled_at, draft_started_at, draft_completed_at,
          created_at, updated_at)
        SELECT id, id, season_id, status, size, draft_mode,
          draft_order_style, current_pick_number, pick_clock_seconds,
          draft_scheduled_at, draft_started_at, draft_completed_at,
          created_at, updated_at
        FROM leagues
      SQL
      execute("SELECT setval('league_seasons_id_seq', GREATEST((SELECT MAX(id) FROM league_seasons), 1))")
    end

    # Participants
    remove_foreign_key :participants, :leagues if foreign_key_exists?(:participants, :leagues)
    remove_index :participants, name: "index_participants_on_league_id" if index_exists?(:participants, :league_id, name: "index_participants_on_league_id")
    remove_index :participants, name: "index_participants_on_league_id_and_draft_position" if index_exists?(:participants, [:league_id, :draft_position], name: "index_participants_on_league_id_and_draft_position")
    remove_index :participants, name: "index_participants_one_owner_per_league" if index_exists?(:participants, :league_id, name: "index_participants_one_owner_per_league")

    rename_column :participants, :league_id, :league_season_id

    add_foreign_key :participants, :league_seasons
    add_index :participants, :league_season_id, name: "index_participants_on_league_season_id"
    add_index :participants, [:league_season_id, :draft_position], unique: true,
      name: "index_participants_on_league_season_id_and_draft_position"
    add_index :participants, :league_season_id, unique: true, where: "is_owner",
      name: "index_participants_one_owner_per_league_season"

    # Draft picks
    remove_foreign_key :draft_picks, :leagues if foreign_key_exists?(:draft_picks, :leagues)
    remove_index :draft_picks, name: "index_draft_picks_on_league_id" if index_exists?(:draft_picks, :league_id, name: "index_draft_picks_on_league_id")
    remove_index :draft_picks, name: "index_draft_picks_on_league_id_and_pick_number" if index_exists?(:draft_picks, [:league_id, :pick_number], name: "index_draft_picks_on_league_id_and_pick_number")
    remove_index :draft_picks, name: "index_draft_picks_on_league_id_and_season_team_id" if index_exists?(:draft_picks, [:league_id, :season_team_id], name: "index_draft_picks_on_league_id_and_season_team_id")

    rename_column :draft_picks, :league_id, :league_season_id

    add_foreign_key :draft_picks, :league_seasons
    add_index :draft_picks, :league_season_id, name: "index_draft_picks_on_league_season_id"
    add_index :draft_picks, [:league_season_id, :pick_number], unique: true,
      name: "index_draft_picks_on_league_season_id_and_pick_number"
    add_index :draft_picks, [:league_season_id, :season_team_id], unique: true,
      name: "index_draft_picks_on_league_season_id_and_season_team_id"
  end

  def down
    # Reverse for completeness; dev-only refactor so unlikely to be invoked.
    remove_foreign_key :draft_picks, :league_seasons
    remove_index :draft_picks, name: "index_draft_picks_on_league_season_id"
    remove_index :draft_picks, name: "index_draft_picks_on_league_season_id_and_pick_number"
    remove_index :draft_picks, name: "index_draft_picks_on_league_season_id_and_season_team_id"
    rename_column :draft_picks, :league_season_id, :league_id
    add_foreign_key :draft_picks, :leagues
    add_index :draft_picks, :league_id
    add_index :draft_picks, [:league_id, :pick_number], unique: true
    add_index :draft_picks, [:league_id, :season_team_id], unique: true

    remove_foreign_key :participants, :league_seasons
    remove_index :participants, name: "index_participants_on_league_season_id"
    remove_index :participants, name: "index_participants_on_league_season_id_and_draft_position"
    remove_index :participants, name: "index_participants_one_owner_per_league_season"
    rename_column :participants, :league_season_id, :league_id
    add_foreign_key :participants, :leagues
    add_index :participants, :league_id
    add_index :participants, [:league_id, :draft_position], unique: true
    add_index :participants, :league_id, unique: true, where: "is_owner"
  end
end
