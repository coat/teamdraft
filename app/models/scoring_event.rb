# frozen_string_literal: true

class ScoringEvent < ApplicationRecord
  EVENT_TYPES = %w[
    regular_win
    playoff_appearance
    divisional_appearance
    conference_appearance
    championship_appearance
    championship_win
  ].freeze

  belongs_to :season_team
  belongs_to :game, optional: true

  validates :event_type, inclusion: {in: EVENT_TYPES}
  validates :points, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :occurred_at, presence: true
  validates :event_type, uniqueness: {scope: [:season_team_id, :game_id]}
end
