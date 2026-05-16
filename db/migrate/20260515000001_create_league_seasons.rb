# frozen_string_literal: true

class CreateLeagueSeasons < ActiveRecord::Migration[8.0]
  def change
    create_table :league_seasons do |t|
      t.references :league, null: false, foreign_key: true
      t.references :season, null: false, foreign_key: true
      t.string :status, null: false, default: "draft_pending"
      t.integer :size, null: false, default: 2
      t.string :draft_mode, null: false, default: "manual"
      t.string :draft_order_style, null: false, default: "snake"
      t.integer :current_pick_number, null: false, default: 1
      t.integer :pick_clock_seconds
      t.datetime :draft_scheduled_at
      t.datetime :draft_started_at
      t.datetime :draft_completed_at
      t.timestamps
    end

    add_index :league_seasons, [:league_id, :season_id], unique: true

    add_check_constraint :league_seasons, "char_length(status::text) > 0", name: "league_seasons_status_not_blank"
    add_check_constraint :league_seasons,
      "status::text = ANY (ARRAY['draft_pending'::character varying, 'drafting'::character varying, 'in_season'::character varying, 'completed'::character varying]::text[])",
      name: "league_seasons_status_valid"
    add_check_constraint :league_seasons,
      "draft_mode::text = ANY (ARRAY['live'::character varying, 'manual'::character varying]::text[])",
      name: "league_seasons_draft_mode_valid"
    add_check_constraint :league_seasons,
      "draft_order_style::text = ANY (ARRAY['snake'::character varying, 'linear'::character varying]::text[])",
      name: "league_seasons_draft_order_style_valid"
    add_check_constraint :league_seasons, "size >= 2 AND size <= 8", name: "league_seasons_size_range"
    add_check_constraint :league_seasons, "current_pick_number >= 1", name: "league_seasons_current_pick_positive"
    add_check_constraint :league_seasons, "pick_clock_seconds IS NULL OR pick_clock_seconds > 0", name: "league_seasons_pick_clock_positive"
  end
end
