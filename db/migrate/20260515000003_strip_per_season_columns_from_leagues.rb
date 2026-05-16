# frozen_string_literal: true

class StripPerSeasonColumnsFromLeagues < ActiveRecord::Migration[8.0]
  CHECK_CONSTRAINTS = %w[
    leagues_current_pick_positive
    leagues_draft_mode_valid
    leagues_draft_order_style_valid
    leagues_pick_clock_positive
    leagues_size_range
    leagues_status_valid
  ].freeze

  COLUMNS = %w[
    current_pick_number
    draft_completed_at
    draft_mode
    draft_order_style
    draft_scheduled_at
    draft_started_at
    pick_clock_seconds
    season_id
    size
    status
  ].freeze

  def up
    CHECK_CONSTRAINTS.each do |name|
      remove_check_constraint :leagues, name: name if check_constraint_exists?(name)
    end

    remove_foreign_key :leagues, :seasons if foreign_key_exists?(:leagues, :seasons)
    remove_index :leagues, name: "index_leagues_on_season_id" if index_exists?(:leagues, :season_id, name: "index_leagues_on_season_id")

    COLUMNS.each do |col|
      remove_column :leagues, col if column_exists?(:leagues, col)
    end
  end

  def down
    add_column :leagues, :season_id, :bigint
    add_column :leagues, :status, :string, default: "draft_pending", null: false
    add_column :leagues, :size, :integer, default: 2, null: false
    add_column :leagues, :draft_mode, :string, default: "manual", null: false
    add_column :leagues, :draft_order_style, :string, default: "snake", null: false
    add_column :leagues, :current_pick_number, :integer, default: 1, null: false
    add_column :leagues, :pick_clock_seconds, :integer
    add_column :leagues, :draft_scheduled_at, :datetime
    add_column :leagues, :draft_started_at, :datetime
    add_column :leagues, :draft_completed_at, :datetime
    add_index :leagues, :season_id
    add_foreign_key :leagues, :seasons
  end

  private

  def check_constraint_exists?(name)
    connection.check_constraints(:leagues).any? { |cc| cc.name == name }
  end
end
