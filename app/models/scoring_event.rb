# frozen_string_literal: true

class ScoringEvent < ApplicationRecord
  belongs_to :season_team
  belongs_to :game, optional: true

  validates :event_type, presence: true
  validates :occurred_at, presence: true
  validates :event_type, uniqueness: {scope: [:season_team_id, :game_id]}
  validate :event_type_known_for_sport

  private

  def event_type_known_for_sport
    return if event_type.blank? || season_team.blank?
    sport = season_team.season&.sport
    return if sport.nil?
    return if sport.scoring_rules.where(event_type: event_type).exists?
    errors.add(:event_type, "is not defined for #{sport.name}")
  end
end
