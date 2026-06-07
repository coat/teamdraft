# frozen_string_literal: true

class Game < ApplicationRecord
  REGULAR_SEASON = "regular_season"
  STATUSES = %w[scheduled in_progress final postponed].freeze

  belongs_to :season
  belongs_to :home_season_team, class_name: "SeasonTeam"
  belongs_to :away_season_team, class_name: "SeasonTeam"
  has_many :scoring_events, dependent: :destroy

  validates :status, inclusion: {in: STATUSES}
  validates :starts_at, presence: true
  validates :external_id, uniqueness: {scope: :season_id, allow_nil: true}
  validate :round_is_known_for_sport
  validate :distinct_teams
  validate :final_games_have_scores

  scope :final, -> { where(status: "final") }
  scope :playoff, -> { where.not(round: REGULAR_SEASON) }
  scope :regular_season, -> { where(round: REGULAR_SEASON) }

  def final?
    status == "final"
  end

  def winner_season_team
    return nil unless final? && home_score && away_score
    return nil if home_score == away_score
    (home_score > away_score) ? home_season_team : away_season_team
  end

  def loser_season_team
    return nil unless final? && home_score && away_score
    return nil if home_score == away_score
    (home_score > away_score) ? away_season_team : home_season_team
  end

  def participants
    [home_season_team, away_season_team]
  end

  private

  def round_is_known_for_sport
    return if round.blank?
    return if round == REGULAR_SEASON
    return if season.blank?
    return if season.sport.scoring_rules.where(round_key: round).exists?
    errors.add(:round, "is not a defined round for #{season.sport.name}")
  end

  def distinct_teams
    return if home_season_team_id.blank? || away_season_team_id.blank?
    errors.add(:away_season_team_id, "must differ from home team") if home_season_team_id == away_season_team_id
  end

  def final_games_have_scores
    return unless final?
    errors.add(:home_score, "is required for final games") if home_score.nil?
    errors.add(:away_score, "is required for final games") if away_score.nil?
  end
end
