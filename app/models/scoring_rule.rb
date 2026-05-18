# frozen_string_literal: true

# Per-sport scoring configuration. Each row is one earnable event for a sport
# (e.g. "regular-season win" or "made the conference finals"). `kind` tells
# Scoring::Recompute how to award it; `round_key` (when present) links a
# playoff-appearance rule to the matching games.round value for that sport.
class ScoringRule < ApplicationRecord
  KINDS = %w[regular_win playoff_appearance championship_win].freeze

  belongs_to :sport
  has_many :league_season_scoring_rules, dependent: :destroy

  validates :event_type, presence: true, uniqueness: {scope: :sport_id}
  validates :kind, inclusion: {in: KINDS}
  validates :round_key, uniqueness: {scope: :sport_id, allow_nil: true}
  validates :points, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :label, presence: true
  validates :short_label, presence: true
  validates :display_order, numericality: {only_integer: true}

  validate :round_key_presence_matches_kind

  scope :ordered, -> { order(:display_order, :id) }

  private

  def round_key_presence_matches_kind
    if kind == "playoff_appearance" && round_key.blank?
      errors.add(:round_key, "is required for playoff_appearance rules")
    elsif kind != "playoff_appearance" && round_key.present?
      errors.add(:round_key, "must be blank unless kind is playoff_appearance")
    end
  end
end
