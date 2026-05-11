# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_10_040000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "draft_picks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "league_id", null: false
    t.bigint "participant_id", null: false
    t.integer "pick_number", null: false
    t.datetime "picked_at", null: false
    t.bigint "season_team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["league_id", "pick_number"], name: "index_draft_picks_on_league_id_and_pick_number", unique: true
    t.index ["league_id", "season_team_id"], name: "index_draft_picks_on_league_id_and_season_team_id", unique: true
    t.index ["league_id"], name: "index_draft_picks_on_league_id"
    t.index ["participant_id"], name: "index_draft_picks_on_participant_id"
    t.index ["season_team_id"], name: "index_draft_picks_on_season_team_id"
    t.check_constraint "pick_number >= 1", name: "draft_picks_pick_number_positive"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "away_score"
    t.bigint "away_season_team_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "external_id"
    t.integer "home_score"
    t.bigint "home_season_team_id", null: false
    t.datetime "kickoff_at", null: false
    t.string "round", default: "regular_season", null: false
    t.bigint "season_id", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.integer "week"
    t.index ["away_season_team_id"], name: "index_games_on_away_season_team_id"
    t.index ["home_season_team_id"], name: "index_games_on_home_season_team_id"
    t.index ["kickoff_at"], name: "index_games_on_kickoff_at"
    t.index ["season_id", "external_id"], name: "index_games_on_season_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["season_id"], name: "index_games_on_season_id"
    t.check_constraint "home_season_team_id <> away_season_team_id", name: "games_distinct_teams"
    t.check_constraint "round::text = ANY (ARRAY['regular_season'::character varying, 'wildcard'::character varying, 'divisional'::character varying, 'conference'::character varying, 'championship'::character varying]::text[])", name: "games_round_valid"
    t.check_constraint "status::text <> 'final'::text OR home_score IS NOT NULL AND away_score IS NOT NULL", name: "games_final_has_scores"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'in_progress'::character varying, 'final'::character varying, 'postponed'::character varying]::text[])", name: "games_status_valid"
  end

  create_table "leagues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_pick_number", default: 1, null: false
    t.datetime "draft_completed_at"
    t.string "draft_mode", default: "manual", null: false
    t.string "draft_order_style", default: "snake", null: false
    t.datetime "draft_scheduled_at"
    t.datetime "draft_started_at"
    t.string "name", null: false
    t.integer "pick_clock_seconds"
    t.boolean "private", default: false, null: false
    t.bigint "season_id", null: false
    t.jsonb "settings", default: {}, null: false
    t.integer "size", default: 2, null: false
    t.citext "slug", null: false
    t.string "status", default: "draft_pending", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_leagues_on_season_id"
    t.index ["slug"], name: "index_leagues_on_slug", unique: true
    t.check_constraint "char_length(name::text) > 0", name: "leagues_name_not_blank"
    t.check_constraint "current_pick_number >= 1", name: "leagues_current_pick_positive"
    t.check_constraint "draft_mode::text = ANY (ARRAY['live'::character varying, 'manual'::character varying]::text[])", name: "leagues_draft_mode_valid"
    t.check_constraint "draft_order_style::text = ANY (ARRAY['snake'::character varying, 'linear'::character varying]::text[])", name: "leagues_draft_order_style_valid"
    t.check_constraint "pick_clock_seconds IS NULL OR pick_clock_seconds > 0", name: "leagues_pick_clock_positive"
    t.check_constraint "size >= 2 AND size <= 8", name: "leagues_size_range"
    t.check_constraint "status::text = ANY (ARRAY['draft_pending'::character varying, 'drafting'::character varying, 'in_season'::character varying, 'completed'::character varying]::text[])", name: "leagues_status_valid"
  end

  create_table "participants", force: :cascade do |t|
    t.citext "claim_token", null: false
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.integer "draft_position", null: false
    t.citext "email"
    t.datetime "invited_at"
    t.boolean "is_owner", default: false, null: false
    t.datetime "joined_at"
    t.bigint "league_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["claim_token"], name: "index_participants_on_claim_token", unique: true
    t.index ["league_id", "draft_position"], name: "index_participants_on_league_id_and_draft_position", unique: true
    t.index ["league_id"], name: "index_participants_on_league_id"
    t.index ["league_id"], name: "index_participants_one_owner_per_league", unique: true, where: "is_owner"
    t.index ["user_id"], name: "index_participants_on_user_id"
    t.check_constraint "char_length(claim_token::text) >= 24", name: "participants_claim_token_length"
    t.check_constraint "char_length(display_name::text) > 0", name: "participants_display_name_not_blank"
    t.check_constraint "draft_position >= 1 AND draft_position <= 8", name: "participants_draft_position_range"
  end

  create_table "scoring_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "game_id"
    t.datetime "occurred_at", null: false
    t.integer "points", null: false
    t.bigint "season_team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_scoring_events_on_game_id"
    t.index ["season_team_id", "game_id", "event_type"], name: "index_scoring_events_unique_per_team_game_type", unique: true
    t.index ["season_team_id", "occurred_at"], name: "index_scoring_events_on_season_team_id_and_occurred_at"
    t.index ["season_team_id"], name: "index_scoring_events_on_season_team_id"
    t.check_constraint "event_type::text = ANY (ARRAY['regular_win'::character varying, 'playoff_appearance'::character varying, 'divisional_appearance'::character varying, 'conference_appearance'::character varying, 'championship_appearance'::character varying, 'championship_win'::character varying]::text[])", name: "scoring_events_event_type_valid"
    t.check_constraint "points >= 0", name: "scoring_events_points_non_negative"
  end

  create_table "season_teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "season_id", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "team_id"], name: "index_season_teams_on_season_id_and_team_id", unique: true
    t.index ["season_id"], name: "index_season_teams_on_season_id"
    t.index ["team_id"], name: "index_season_teams_on_team_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.string "external_id"
    t.string "external_provider"
    t.string "label", null: false
    t.bigint "sport_id", null: false
    t.date "starts_on"
    t.string "status", default: "upcoming", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["sport_id", "year"], name: "index_seasons_on_sport_id_and_year", unique: true
    t.index ["sport_id"], name: "index_seasons_on_sport_id"
    t.check_constraint "ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on", name: "seasons_dates_ordered"
    t.check_constraint "status::text = ANY (ARRAY['upcoming'::character varying, 'active'::character varying, 'completed'::character varying]::text[])", name: "seasons_status_valid"
    t.check_constraint "year >= 1900 AND year <= 2100", name: "seasons_year_range"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sports", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.citext "key", null: false
    t.string "name", null: false
    t.jsonb "scoring_rules", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_sports_on_key", unique: true
    t.check_constraint "char_length(name::text) > 0", name: "sports_name_not_blank"
  end

  create_table "teams", force: :cascade do |t|
    t.citext "abbreviation", null: false
    t.string "conference"
    t.datetime "created_at", null: false
    t.integer "default_pick_rank"
    t.string "division"
    t.string "external_id"
    t.string "logo_url"
    t.string "name", null: false
    t.string "primary_color"
    t.citext "slug", null: false
    t.bigint "sport_id", null: false
    t.datetime "updated_at", null: false
    t.index ["sport_id", "abbreviation"], name: "index_teams_on_sport_id_and_abbreviation", unique: true
    t.index ["sport_id", "default_pick_rank"], name: "index_teams_on_sport_id_and_default_pick_rank"
    t.index ["sport_id", "external_id"], name: "index_teams_on_sport_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["sport_id", "slug"], name: "index_teams_on_sport_id_and_slug", unique: true
    t.index ["sport_id"], name: "index_teams_on_sport_id"
    t.check_constraint "char_length(abbreviation::text) > 0", name: "teams_abbr_not_blank"
    t.check_constraint "char_length(name::text) > 0", name: "teams_name_not_blank"
    t.check_constraint "default_pick_rank IS NULL OR default_pick_rank > 0", name: "teams_default_pick_rank_positive"
    t.check_constraint "slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::citext", name: "teams_slug_format"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.citext "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "email_address ~* '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'::citext", name: "users_email_format"
  end

  add_foreign_key "draft_picks", "leagues", on_delete: :cascade
  add_foreign_key "draft_picks", "participants", on_delete: :restrict
  add_foreign_key "draft_picks", "season_teams", on_delete: :restrict
  add_foreign_key "games", "season_teams", column: "away_season_team_id", on_delete: :restrict
  add_foreign_key "games", "season_teams", column: "home_season_team_id", on_delete: :restrict
  add_foreign_key "games", "seasons", on_delete: :cascade
  add_foreign_key "leagues", "seasons", on_delete: :restrict
  add_foreign_key "participants", "leagues", on_delete: :cascade
  add_foreign_key "participants", "users", on_delete: :nullify
  add_foreign_key "scoring_events", "games", on_delete: :cascade
  add_foreign_key "scoring_events", "season_teams", on_delete: :cascade
  add_foreign_key "season_teams", "seasons", on_delete: :cascade
  add_foreign_key "season_teams", "teams", on_delete: :restrict
  add_foreign_key "seasons", "sports", on_delete: :restrict
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "teams", "sports", on_delete: :restrict
end
