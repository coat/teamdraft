# frozen_string_literal: true

# Linear ordering on a model row within some scope. Adopters declare:
#
#   class Participant < ApplicationRecord
#     include Positional
#     acts_positional column: :draft_position, scope: :league_season_id
#   end
#
# The DB-side uniqueness on (scope..., column) must be `DEFERRABLE INITIALLY
# IMMEDIATE` (see `participants` and `user_team_rankings` schemas). Swaps
# defer constraints for the duration of the transaction so two rows can
# trade values atomically without tripping the per-row check.
#
# `update_columns` skips callbacks, so any after_save side-effects (turbo
# broadcasts, etc.) must be reissued from `after_position_swap`, which
# adopters can override.
module Positional
  extend ActiveSupport::Concern

  class_methods do
    def acts_positional(column:, scope:)
      class_attribute :positional_column, default: column.to_sym
      class_attribute :positional_scope_keys, default: Array(scope).map(&:to_sym)
    end
  end

  def move_up!
    swap_with_neighbour(:above)
  end

  def move_down!
    swap_with_neighbour(:below)
  end

  def swap_position_with(other)
    column = self.class.positional_column
    self.class.transaction do
      self.class.connection.execute("SET CONSTRAINTS ALL DEFERRED")
      a_val = self[column]
      update_columns(column => other[column])
      other.update_columns(column => a_val)
    end
    after_position_swap
    true
  end

  private

  def swap_with_neighbour(direction)
    neighbour = positional_neighbour(direction)
    return false unless neighbour
    swap_position_with(neighbour)
  end

  def positional_neighbour(direction)
    column = self.class.positional_column
    scope = self.class.where.not(id: id)
    self.class.positional_scope_keys.each { |k| scope = scope.where(k => self[k]) }
    if direction == :above
      scope.where(column => ...self[column]).order(column => :desc).first
    else
      scope.where(column => (self[column] + 1)..).order(column => :asc).first
    end
  end

  # Hook for adopters that need to reissue side-effects skipped by
  # `update_columns` (e.g. Turbo broadcasts). Default: nothing.
  def after_position_swap
  end
end
