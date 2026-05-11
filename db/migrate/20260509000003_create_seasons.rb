# frozen_string_literal: true

class CreateSeasons < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.references :sport, null: false, foreign_key: {on_delete: :restrict}
      t.integer :year, null: false
      t.string :label, null: false
      t.date :starts_on
      t.date :ends_on
      t.string :status, null: false, default: "upcoming"
      t.string :external_provider
      t.string :external_id
      t.timestamps
    end

    add_index :seasons, [:sport_id, :year], unique: true
    add_check_constraint :seasons,
      "status IN ('upcoming','active','completed')",
      name: "seasons_status_valid"
    add_check_constraint :seasons,
      "year BETWEEN 1900 AND 2100",
      name: "seasons_year_range"
    add_check_constraint :seasons,
      "ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on",
      name: "seasons_dates_ordered"
  end
end
