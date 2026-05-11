# frozen_string_literal: true

class SeasonTeam < ApplicationRecord
  belongs_to :season
  belongs_to :team
  has_many :draft_picks, dependent: :restrict_with_exception
  has_many :scoring_events, dependent: :destroy
  has_many :home_games, class_name: "Game", foreign_key: :home_season_team_id, dependent: :restrict_with_exception, inverse_of: :home_season_team
  has_many :away_games, class_name: "Game", foreign_key: :away_season_team_id, dependent: :restrict_with_exception, inverse_of: :away_season_team

  validates :team_id, uniqueness: {scope: :season_id}
  validate :team_and_season_share_sport

  private

  def team_and_season_share_sport
    return if team.blank? || season.blank?
    errors.add(:team, "must belong to the season's sport") if team.sport_id != season.sport_id
  end
end
