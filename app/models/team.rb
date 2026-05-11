# frozen_string_literal: true

class Team < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  belongs_to :sport
  has_many :season_teams, dependent: :restrict_with_exception
  has_many :seasons, through: :season_teams

  validates :name, presence: true
  validates :abbreviation, presence: true,
    uniqueness: {scope: :sport_id, case_sensitive: false}
  validates :slug, presence: true,
    uniqueness: {scope: :sport_id, case_sensitive: false},
    format: {with: SLUG_FORMAT}
  validates :external_id, uniqueness: {scope: :sport_id, allow_nil: true}
end
