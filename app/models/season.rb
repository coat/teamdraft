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
  validate :round_windows_valid

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

  # Maps an Eastern-time game date to a playoff round key using the
  # admin-configured windows, or nil when no window covers it (callers
  # treat nil as regular season). Windows are stored as
  # {"wildcard" => {"starts_on" => "2026-09-29", "ends_on" => "2026-10-02"}}.
  def round_for(date)
    return nil if date.nil?
    parsed_round_windows.find { |_key, range| range.cover?(date) }&.first
  end

  private

  def ends_after_starts
    return if starts_on.blank? || ends_on.blank?
    errors.add(:ends_on, "must be on or after starts_on") if ends_on < starts_on
  end

  def parsed_round_windows
    round_windows.filter_map do |key, window|
      next unless window.is_a?(Hash)
      starts = safe_date(window["starts_on"])
      ends = safe_date(window["ends_on"])
      [key, starts..ends] if starts && ends
    end
  end

  def safe_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def round_windows_valid
    return if round_windows.blank?
    unless round_windows.is_a?(Hash)
      errors.add(:round_windows, "must be a map of round keys to date windows")
      return
    end
    allowed = sport ? sport.scoring_rules.where(kind: "playoff_appearance").pluck(:round_key) : []
    parsed = []
    round_windows.each do |key, window|
      unless allowed.include?(key)
        errors.add(:round_windows, "#{key.inspect} is not a playoff round for this sport")
        next
      end
      starts = window.is_a?(Hash) ? safe_date(window["starts_on"]) : nil
      ends = window.is_a?(Hash) ? safe_date(window["ends_on"]) : nil
      if starts.nil? || ends.nil?
        errors.add(:round_windows, "#{key} needs both starts_on and ends_on dates")
      elsif ends < starts
        errors.add(:round_windows, "#{key} ends_on must be on or after starts_on")
      elsif starts_on && ends_on && (starts < starts_on || ends > ends_on)
        errors.add(:round_windows, "#{key} window must fall within the season")
      else
        parsed << [key, starts..ends]
      end
    end
    parsed.combination(2).each do |(k1, r1), (k2, r2)|
      errors.add(:round_windows, "#{k1} and #{k2} windows overlap") if r1.cover?(r2.first) || r2.cover?(r1.first)
    end
  end
end
