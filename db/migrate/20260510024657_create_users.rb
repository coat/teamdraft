# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.citext :email_address, null: false
      t.string :password_digest, null: false
      t.boolean :admin, null: false, default: false
      t.timestamps
    end

    add_index :users, :email_address, unique: true

    add_check_constraint :users,
      "email_address ~* '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'",
      name: "users_email_format"
  end
end
