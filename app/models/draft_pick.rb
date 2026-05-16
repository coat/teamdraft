# frozen_string_literal: true

class DraftPick < ApplicationRecord
  belongs_to :league_season, inverse_of: :draft_picks
  belongs_to :participant
  belongs_to :season_team

  has_one :team, through: :season_team

  before_validation :set_picked_at, on: :create

  validates :pick_number, presence: true,
    numericality: {only_integer: true, greater_than_or_equal_to: 1},
    uniqueness: {scope: :league_season_id}
  validates :season_team_id, uniqueness: {scope: :league_season_id, message: "already drafted in this league season"}
  validates :picked_at, presence: true
  validate :participant_belongs_to_league_season
  validate :season_team_belongs_to_league_season

  private

  def set_picked_at
    self.picked_at ||= Time.current
  end

  def participant_belongs_to_league_season
    return if participant.blank? || league_season.blank?
    errors.add(:participant, "is not in this league season") if participant.league_season_id != league_season.id
  end

  def season_team_belongs_to_league_season
    return if season_team.blank? || league_season.blank?
    errors.add(:season_team, "is from a different season") if season_team.season_id != league_season.season_id
  end
end
