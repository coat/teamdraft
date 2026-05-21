# frozen_string_literal: true

# Lets us control the order sports appear in user-facing lists (e.g. the
# About page's per-sport tabs) without leaking install order or relying on
# alphabetical name. Mirrors the scoring_rules.display_order pattern.
class AddDisplayOrderToSports < ActiveRecord::Migration[8.1]
  def up
    add_column :sports, :display_order, :integer, null: false, default: 0
    execute <<~SQL
      UPDATE sports SET display_order = CASE key::text
        WHEN 'nfl' THEN 1
        WHEN 'mlb' THEN 2
        WHEN 'nba' THEN 3
        ELSE 0
      END
    SQL
  end

  def down
    remove_column :sports, :display_order
  end
end
