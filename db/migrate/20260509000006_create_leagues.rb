# frozen_string_literal: true

class CreateLeagues < ActiveRecord::Migration[8.1]
  def change
    create_table :leagues do |t|
      t.citext :slug, null: false
      t.string :name, null: false
      t.references :season, null: false, foreign_key: {on_delete: :restrict}
      t.integer :size, null: false, default: 2
      t.string :draft_mode, null: false, default: "manual"
      t.string :draft_order_style, null: false, default: "snake"
      t.datetime :draft_scheduled_at
      t.datetime :draft_started_at
      t.datetime :draft_completed_at
      t.integer :pick_clock_seconds
      t.integer :current_pick_number, null: false, default: 1
      t.string :status, null: false, default: "draft_pending"
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end

    add_index :leagues, :slug, unique: true

    add_check_constraint :leagues, "size BETWEEN 2 AND 8", name: "leagues_size_range"
    add_check_constraint :leagues, "current_pick_number >= 1", name: "leagues_current_pick_positive"
    add_check_constraint :leagues,
      "pick_clock_seconds IS NULL OR pick_clock_seconds > 0",
      name: "leagues_pick_clock_positive"
    add_check_constraint :leagues,
      "draft_mode IN ('live','manual')",
      name: "leagues_draft_mode_valid"
    add_check_constraint :leagues,
      "draft_order_style IN ('snake','linear')",
      name: "leagues_draft_order_style_valid"
    add_check_constraint :leagues,
      "status IN ('draft_pending','drafting','in_season','completed')",
      name: "leagues_status_valid"
    add_check_constraint :leagues, "char_length(name) > 0", name: "leagues_name_not_blank"
  end
end
