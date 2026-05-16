# frozen_string_literal: true

class LeagueSeason < ApplicationRecord
  DRAFT_MODES = %w[live manual].freeze
  DRAFT_ORDER_STYLES = %w[snake linear].freeze
  STATUSES = %w[draft_pending drafting in_season completed].freeze

  belongs_to :league, inverse_of: :league_seasons
  belongs_to :season
  has_many :participants, -> { order(:draft_position) }, dependent: :destroy, inverse_of: :league_season
  has_many :draft_picks, -> { order(:pick_number) }, dependent: :destroy, inverse_of: :league_season

  broadcasts_refreshes_to ->(ls) { ls.league }

  validates :season_id, uniqueness: {scope: :league_id}
  validates :size, numericality: {only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 8}
  validates :draft_mode, inclusion: {in: DRAFT_MODES}
  validates :draft_order_style, inclusion: {in: DRAFT_ORDER_STYLES}
  validates :status, inclusion: {in: STATUSES}
  validates :current_pick_number, numericality: {only_integer: true, greater_than_or_equal_to: 1}
  validates :pick_clock_seconds, numericality: {only_integer: true, greater_than: 0}, allow_nil: true

  def owner
    participants.find_by(is_owner: true)
  end

  def draft_finished?
    %w[in_season completed].include?(status)
  end

  def picks_per_participant
    season.season_teams.count / size
  end

  def total_picks
    picks_per_participant * size
  end
end
