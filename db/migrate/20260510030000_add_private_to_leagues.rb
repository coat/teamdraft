# frozen_string_literal: true

class AddPrivateToLeagues < ActiveRecord::Migration[8.1]
  def change
    add_column :leagues, :private, :boolean, default: false, null: false
  end
end
