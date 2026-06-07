# frozen_string_literal: true

class Season < ApplicationRecord
  STATUSES = %w[upcoming active completed].freeze

  # Tuning knobs for Sync::RefreshActiveSeasonsJob's per-season gating.
  # The pre-window covers warm-up; the post-window covers the longest games
  # plus a tail for stat corrections. The fallback guarantees we still poll a
  # few times overnight in case a final score is adjusted hours later.
  SYNC_WINDOW_BEFORE = 30.minutes
  SYNC_WINDOW_AFTER = 6.hours
  SYNC_OVERNIGHT_FALLBACK = 3.hours

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

  # Returns the gating reason for Sync::RefreshActiveSeasonsJob, or nil if the
  # season can be skipped on this tick. Reasons: :window (a game is about to
  # start, in play, or just finished), :live (in_progress safety net),
  # :fallback (no relevant games but we haven't synced in a while).
  def score_sync_reason(now: Time.current)
    window = (now - SYNC_WINDOW_AFTER)..(now + SYNC_WINDOW_BEFORE)
    return :window if games.where(starts_at: window).exists?
    return :live if games.where(status: "in_progress").exists?
    return :fallback if last_synced_at.nil? || last_synced_at < now - SYNC_OVERNIGHT_FALLBACK
    nil
  end

  private

  def ends_after_starts
    return if starts_on.blank? || ends_on.blank?
    errors.add(:ends_on, "must be on or after starts_on") if ends_on < starts_on
  end
end
