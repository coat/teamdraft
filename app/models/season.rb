# frozen_string_literal: true

class Season < ApplicationRecord
  STATUSES = %w[upcoming active completed].freeze

  scope :active, -> { where(status: "active") }

  belongs_to :sport
  has_many :season_teams, dependent: :destroy
  has_many :teams, through: :season_teams
  has_many :league_seasons, dependent: :restrict_with_exception
  has_many :leagues, through: :league_seasons
  has_many :games, dependent: :destroy

  validates :year, presence: true,
    numericality: {only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: 2100},
    uniqueness: {scope: :sport_id}
  validates :label, presence: true
  validates :status, inclusion: {in: STATUSES}
  validate :ends_after_starts

  private

  def ends_after_starts
    return if starts_on.blank? || ends_on.blank?
    errors.add(:ends_on, "must be on or after starts_on") if ends_on < starts_on
  end
end
