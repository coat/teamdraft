# frozen_string_literal: true

class CreateSports < ActiveRecord::Migration[8.1]
  def change
    create_table :sports do |t|
      t.citext :key, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.jsonb :scoring_rules, null: false, default: {}
      t.timestamps
    end

    add_index :sports, :key, unique: true
    add_check_constraint :sports, "char_length(name) > 0", name: "sports_name_not_blank"
  end
end
