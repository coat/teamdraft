# frozen_string_literal: true

class LinkParticipantsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :participants, :users, on_delete: :nullify
  end
end
