# frozen_string_literal: true

class League < ApplicationRecord
  extend FriendlyId

  friendly_id :slug_candidate, use: [:slugged, :history], slug_column: :slug

  broadcasts_refreshes

  DRAFT_MODES = %w[live manual].freeze
  DRAFT_ORDER_STYLES = %w[snake linear].freeze
  STATUSES = %w[draft_pending drafting in_season completed].freeze

  belongs_to :season
  has_many :participants, -> { order(:draft_position) }, dependent: :destroy, inverse_of: :league
  has_many :draft_picks, -> { order(:pick_number) }, dependent: :destroy, inverse_of: :league

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: {case_sensitive: false}
  validates :size, numericality: {only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 8}
  validates :draft_mode, inclusion: {in: DRAFT_MODES}
  validates :draft_order_style, inclusion: {in: DRAFT_ORDER_STYLES}
  validates :status, inclusion: {in: STATUSES}
  validates :current_pick_number, numericality: {only_integer: true, greater_than_or_equal_to: 1}
  validates :pick_clock_seconds, numericality: {only_integer: true, greater_than: 0}, allow_nil: true

  def owner
    participants.find_by(is_owner: true)
  end

  def picks_per_participant
    season.season_teams.count / size
  end

  def total_picks
    picks_per_participant * size
  end

  # Used by friendly_id when generating a slug. The custom controller path
  # passes a haikunated string in via :slug_candidate.
  attr_accessor :slug_candidate

  def should_generate_new_friendly_id?
    slug.blank? || slug_candidate.present?
  end
end
