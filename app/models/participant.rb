# frozen_string_literal: true

class Participant < ApplicationRecord
  CLAIM_TOKEN_BYTES = 24

  belongs_to :league_season, inverse_of: :participants
  belongs_to :user, optional: true
  has_many :draft_picks, dependent: :restrict_with_exception

  delegate :league, to: :league_season

  broadcasts_refreshes_to ->(p) { p.league }

  before_validation :assign_claim_token, on: :create

  validates :display_name, presence: true
  validates :draft_position, numericality: {only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 8},
    uniqueness: {scope: :league_season_id}
  validates :claim_token, presence: true, uniqueness: true, length: {minimum: 24}
  validate :draft_position_within_league_size

  scope :owners, -> { where(is_owner: true) }

  private

  def assign_claim_token
    self.claim_token ||= SecureRandom.urlsafe_base64(CLAIM_TOKEN_BYTES)
  end

  def draft_position_within_league_size
    return if league_season.blank? || draft_position.blank?
    errors.add(:draft_position, "exceeds league size") if draft_position > league_season.size
  end
end
