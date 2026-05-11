# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.references :sport, null: false, foreign_key: {on_delete: :restrict}
      t.string :name, null: false
      t.citext :abbreviation, null: false
      t.citext :slug, null: false
      t.string :external_id
      t.string :conference
      t.string :division
      t.string :primary_color
      t.string :logo_url
      t.timestamps
    end

    add_index :teams, [:sport_id, :slug], unique: true
    add_index :teams, [:sport_id, :abbreviation], unique: true
    add_index :teams, [:sport_id, :external_id],
      unique: true,
      where: "external_id IS NOT NULL",
      name: "index_teams_on_sport_and_external_id"

    add_check_constraint :teams, "char_length(name) > 0", name: "teams_name_not_blank"
    add_check_constraint :teams, "char_length(abbreviation) > 0", name: "teams_abbr_not_blank"
    add_check_constraint :teams, "slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'", name: "teams_slug_format"
  end
end
