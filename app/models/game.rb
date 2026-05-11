# frozen_string_literal: true

class Game < ApplicationRecord
  ROUNDS = %w[regular_season wildcard divisional conference championship].freeze
  STATUSES = %w[scheduled in_progress final postponed].freeze

  belongs_to :season
  belongs_to :home_season_team, class_name: "SeasonTeam"
  belongs_to :away_season_team, class_name: "SeasonTeam"
  has_many :scoring_events, dependent: :destroy

  validates :round, inclusion: {in: ROUNDS}
  validates :status, inclusion: {in: STATUSES}
  validates :kickoff_at, presence: true
  validates :external_id, uniqueness: {scope: :season_id, allow_nil: true}
  validate :distinct_teams
  validate :final_games_have_scores

  scope :final, -> { where(status: "final") }
  scope :playoff, -> { where.not(round: "regular_season") }
  scope :regular_season, -> { where(round: "regular_season") }

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
