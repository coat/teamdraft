# frozen_string_literal: true

class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.references :league, null: false, foreign_key: {on_delete: :cascade}
      t.string :display_name, null: false
      t.citext :email
      t.integer :draft_position, null: false
      t.bigint :user_id
      t.citext :claim_token, null: false
      t.boolean :is_owner, null: false, default: false
      t.datetime :invited_at
      t.datetime :joined_at
      t.timestamps
    end

    add_index :participants, :claim_token, unique: true
    add_index :participants, [:league_id, :draft_position], unique: true
    add_index :participants, :user_id
    add_index :participants, :league_id,
      unique: true,
      where: "is_owner",
      name: "index_participants_one_owner_per_league"

    add_check_constraint :participants,
      "draft_position BETWEEN 1 AND 8",
      name: "participants_draft_position_range"
    add_check_constraint :participants,
      "char_length(display_name) > 0",
      name: "participants_display_name_not_blank"
    add_check_constraint :participants,
      "char_length(claim_token) >= 24",
      name: "participants_claim_token_length"
  end
end
