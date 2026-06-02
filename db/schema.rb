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

ActiveRecord::Schema[8.1].define(version: 2026_06_01_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "draft_picks", force: :cascade do |t|
    t.boolean "autopicked", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "league_season_id", null: false
    t.bigint "participant_id", null: false
    t.integer "pick_number", null: false
    t.datetime "picked_at", null: false
    t.bigint "season_team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["league_season_id", "pick_number"], name: "index_draft_picks_on_league_season_id_and_pick_number", unique: true
    t.index ["league_season_id", "season_team_id"], name: "index_draft_picks_on_league_season_id_and_season_team_id", unique: true
    t.index ["league_season_id"], name: "index_draft_picks_on_league_season_id"
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
    t.check_constraint "status::text <> 'final'::text OR home_score IS NOT NULL AND away_score IS NOT NULL", name: "games_final_has_scores"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying::text, 'in_progress'::character varying::text, 'final'::character varying::text, 'postponed'::character varying::text])", name: "games_status_valid"
  end

  create_table "league_season_scoring_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "league_season_id", null: false
    t.integer "points", default: 0, null: false
    t.bigint "scoring_rule_id", null: false
    t.datetime "updated_at", null: false
    t.index ["league_season_id", "scoring_rule_id"], name: "idx_lssr_on_league_season_and_rule", unique: true
    t.index ["league_season_id"], name: "index_league_season_scoring_rules_on_league_season_id"
    t.index ["scoring_rule_id"], name: "index_league_season_scoring_rules_on_scoring_rule_id"
    t.check_constraint "points >= 0", name: "lssr_points_non_negative"
  end

  create_table "league_seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_pick_number", default: 1, null: false
    t.datetime "draft_completed_at"
    t.string "draft_mode", default: "manual", null: false
    t.string "draft_order_style", default: "snake", null: false
    t.datetime "draft_scheduled_at"
    t.datetime "draft_started_at"
    t.string "invite_code", null: false
    t.bigint "league_id", null: false
    t.integer "pick_clock_seconds"
    t.bigint "season_id", null: false
    t.integer "size", default: 2, null: false
    t.string "status", default: "draft_pending", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_code"], name: "index_league_seasons_on_invite_code", unique: true
    t.index ["league_id", "season_id"], name: "index_league_seasons_on_league_id_and_season_id", unique: true
    t.index ["league_id"], name: "index_league_seasons_on_league_id"
    t.index ["season_id"], name: "index_league_seasons_on_season_id"
    t.check_constraint "char_length(status::text) > 0", name: "league_seasons_status_not_blank"
    t.check_constraint "current_pick_number >= 1", name: "league_seasons_current_pick_positive"
    t.check_constraint "draft_mode::text = ANY (ARRAY['live'::character varying::text, 'manual'::character varying::text])", name: "league_seasons_draft_mode_valid"
    t.check_constraint "draft_order_style::text = ANY (ARRAY['snake'::character varying::text, 'linear'::character varying::text])", name: "league_seasons_draft_order_style_valid"
    t.check_constraint "pick_clock_seconds IS NULL OR pick_clock_seconds > 0", name: "league_seasons_pick_clock_positive"
    t.check_constraint "size >= 2 AND size <= 8", name: "league_seasons_size_range"
    t.check_constraint "status::text = ANY (ARRAY['draft_pending'::character varying::text, 'drafting'::character varying::text, 'in_season'::character varying::text, 'completed'::character varying::text])", name: "league_seasons_status_valid"
  end

  create_table "leagues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "private", default: false, null: false
    t.jsonb "settings", default: {}, null: false
    t.citext "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_leagues_on_slug", unique: true
    t.check_constraint "char_length(name::text) > 0", name: "leagues_name_not_blank"
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
    t.bigint "league_season_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["claim_token"], name: "index_participants_on_claim_token", unique: true
    t.index ["league_season_id"], name: "index_participants_on_league_season_id"
    t.index ["league_season_id"], name: "index_participants_one_owner_per_league_season", unique: true, where: "is_owner"
    t.index ["user_id"], name: "index_participants_on_user_id"
    t.check_constraint "char_length(claim_token::text) >= 24", name: "participants_claim_token_length"
    t.check_constraint "char_length(display_name::text) > 0", name: "participants_display_name_not_blank"
    t.check_constraint "draft_position >= 1 AND draft_position <= 8", name: "participants_draft_position_range"
    t.unique_constraint ["league_season_id", "draft_position"], deferrable: :immediate, name: "participants_league_season_id_draft_position_unique"
  end

  create_table "scoring_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "game_id"
    t.datetime "occurred_at", null: false
    t.bigint "season_team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_scoring_events_on_game_id"
    t.index ["season_team_id", "game_id", "event_type"], name: "index_scoring_events_unique_per_team_game_type", unique: true
    t.index ["season_team_id", "occurred_at"], name: "index_scoring_events_on_season_team_id_and_occurred_at"
    t.index ["season_team_id"], name: "index_scoring_events_on_season_team_id"
  end

  create_table "scoring_rules", force: :cascade do |t|
    t.boolean "bye_backfill", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0, null: false
    t.string "event_type", null: false
    t.string "kind", null: false
    t.string "label", null: false
    t.integer "points", default: 0, null: false
    t.string "round_key"
    t.string "short_label", null: false
    t.bigint "sport_id", null: false
    t.datetime "updated_at", null: false
    t.index ["sport_id", "event_type"], name: "index_scoring_rules_unique_event_per_sport", unique: true
    t.index ["sport_id", "round_key"], name: "index_scoring_rules_unique_round_per_sport", unique: true, where: "(round_key IS NOT NULL)"
    t.index ["sport_id"], name: "index_scoring_rules_on_sport_id"
    t.check_constraint "kind::text = ANY (ARRAY['regular_win'::character varying::text, 'playoff_appearance'::character varying::text, 'championship_win'::character varying::text])", name: "scoring_rules_kind_valid"
    t.check_constraint "points >= 0", name: "scoring_rules_points_non_negative"
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
    t.datetime "last_synced_at"
    t.bigint "sport_id", null: false
    t.date "starts_on"
    t.string "status", default: "upcoming", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["sport_id", "year"], name: "index_seasons_on_sport_id_and_year", unique: true
    t.index ["sport_id"], name: "index_seasons_on_sport_id"
    t.check_constraint "ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on", name: "seasons_dates_ordered"
    t.check_constraint "status::text = ANY (ARRAY['upcoming'::character varying::text, 'active'::character varying::text, 'completed'::character varying::text])", name: "seasons_status_valid"
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

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sports", force: :cascade do |t|
    t.text "about_blurb"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0, null: false
    t.citext "key", null: false
    t.string "name", null: false
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
    t.index ["sport_id", "default_pick_rank"], name: "index_teams_on_sport_id_and_default_pick_rank", unique: true
    t.index ["sport_id", "external_id"], name: "index_teams_on_sport_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["sport_id", "slug"], name: "index_teams_on_sport_id_and_slug", unique: true
    t.index ["sport_id"], name: "index_teams_on_sport_id"
    t.check_constraint "char_length(abbreviation::text) > 0", name: "teams_abbr_not_blank"
    t.check_constraint "char_length(name::text) > 0", name: "teams_name_not_blank"
    t.check_constraint "default_pick_rank IS NULL OR default_pick_rank > 0", name: "teams_default_pick_rank_positive"
    t.check_constraint "slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'::citext", name: "teams_slug_format"
  end

  create_table "user_team_rankings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "rank", null: false
    t.bigint "sport_id", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["sport_id"], name: "index_user_team_rankings_on_sport_id"
    t.index ["team_id"], name: "index_user_team_rankings_on_team_id"
    t.index ["user_id", "sport_id"], name: "index_user_team_rankings_on_user_id_and_sport_id"
    t.index ["user_id", "team_id"], name: "index_user_team_rankings_on_user_id_and_team_id", unique: true
    t.index ["user_id"], name: "index_user_team_rankings_on_user_id"
    t.check_constraint "rank > 0", name: "user_team_rankings_rank_positive"
    t.unique_constraint ["user_id", "sport_id", "rank"], deferrable: :immediate, name: "user_team_rankings_user_sport_rank_unique"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.citext "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["disabled_at"], name: "index_users_on_disabled_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "email_address ~* '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'::citext", name: "users_email_format"
  end

  add_foreign_key "draft_picks", "league_seasons"
  add_foreign_key "draft_picks", "participants", on_delete: :restrict
  add_foreign_key "draft_picks", "season_teams", on_delete: :restrict
  add_foreign_key "games", "season_teams", column: "away_season_team_id", on_delete: :restrict
  add_foreign_key "games", "season_teams", column: "home_season_team_id", on_delete: :restrict
  add_foreign_key "games", "seasons", on_delete: :cascade
  add_foreign_key "league_season_scoring_rules", "league_seasons", on_delete: :cascade
  add_foreign_key "league_season_scoring_rules", "scoring_rules", on_delete: :cascade
  add_foreign_key "league_seasons", "leagues"
  add_foreign_key "league_seasons", "seasons"
  add_foreign_key "participants", "league_seasons"
  add_foreign_key "participants", "users", on_delete: :nullify
  add_foreign_key "scoring_events", "games", on_delete: :cascade
  add_foreign_key "scoring_events", "season_teams", on_delete: :cascade
  add_foreign_key "scoring_rules", "sports", on_delete: :cascade
  add_foreign_key "season_teams", "seasons", on_delete: :cascade
  add_foreign_key "season_teams", "teams", on_delete: :restrict
  add_foreign_key "seasons", "sports", on_delete: :restrict
  add_foreign_key "sessions", "users", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "teams", "sports", on_delete: :restrict
  add_foreign_key "user_team_rankings", "sports", on_delete: :cascade
  add_foreign_key "user_team_rankings", "teams", on_delete: :cascade
  add_foreign_key "user_team_rankings", "users", on_delete: :cascade
end
