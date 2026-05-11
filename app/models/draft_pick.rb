# frozen_string_literal: true

class DraftPick < ApplicationRecord
  belongs_to :league, inverse_of: :draft_picks
  belongs_to :participant
  belongs_to :season_team

  has_one :team, through: :season_team

  before_validation :set_picked_at, on: :create

  validates :pick_number, presence: true,
    numericality: {only_integer: true, greater_than_or_equal_to: 1},
    uniqueness: {scope: :league_id}
  validates :season_team_id, uniqueness: {scope: :league_id, message: "already drafted in this league"}
  validates :picked_at, presence: true
  validate :participant_belongs_to_league
  validate :season_team_belongs_to_league_season

  private

  def set_picked_at
    self.picked_at ||= Time.current
  end

  def participant_belongs_to_league
    return if participant.blank? || league.blank?
    errors.add(:participant, "is not in this league") if participant.league_id != league.id
  end

  def season_team_belongs_to_league_season
    return if season_team.blank? || league.blank?
    errors.add(:season_team, "is from a different season") if season_team.season_id != league.season_id
  end
end
