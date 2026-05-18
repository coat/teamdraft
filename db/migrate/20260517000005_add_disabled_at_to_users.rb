# frozen_string_literal: true

# Soft-disable for user accounts. Admin can disable an account from the new
# users admin page; disabled users are blocked from signing in and have their
# active sessions destroyed. Nullable timestamp doubles as "when was this
# done?" without a separate audit column.
class AddDisabledAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :disabled_at, :datetime
    add_index :users, :disabled_at
  end
end
