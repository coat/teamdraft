# frozen_string_literal: true

class LeagueSeason < ApplicationRecord
  DRAFT_MODES = %w[live manual].freeze
  DRAFT_ORDER_STYLES = %w[snake linear].freeze
  STATUSES = %w[draft_pending drafting in_season completed].freeze
  DEFAULT_PICK_CLOCK_SECONDS = 120

  belongs_to :league, inverse_of: :league_seasons
  belongs_to :season
  has_many :draft_picks, -> { order(:pick_number) }, dependent: :destroy, inverse_of: :league_season
  has_many :participants, -> { order(:draft_position) }, dependent: :destroy, inverse_of: :league_season
  has_many :scoring_rule_overrides, class_name: "LeagueSeasonScoringRule", dependent: :destroy

  broadcasts_refreshes_to ->(ls) { ls.league }

  before_validation :assign_invite_code, on: :create
  before_validation :normalize_for_draft_mode

  validates :season_id, uniqueness: {scope: :league_id}
  validates :size, numericality: {only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 8}
  validates :draft_mode, inclusion: {in: DRAFT_MODES}
  validates :draft_order_style, inclusion: {in: DRAFT_ORDER_STYLES}
  validates :status, inclusion: {in: STATUSES}
  validates :current_pick_number, numericality: {only_integer: true, greater_than_or_equal_to: 1}
  validates :pick_clock_seconds, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
  validates :invite_code, presence: true, uniqueness: {case_sensitive: false}

  def self.generate_unique_invite_code
    loop do
      candidate = Haikunator.haikunate(999)
      return candidate unless exists?(invite_code: candidate)
    end
  end

  # Audibly-shared codes are typo-prone; ignore case and surrounding whitespace.
  def verify_invite!(candidate)
    candidate.to_s.strip.casecmp(invite_code.to_s).zero?
  end

  def owner
    participants.find_by(is_owner: true)
  end

  def draft_finished?
    %w[in_season completed].include?(status)
  end

  def started?
    draft_picks.any?
  end

  def manual_mode? = draft_mode == "manual"

  def live_mode? = draft_mode == "live"

  # The participant whose turn it is, or nil if the draft is complete.
  # Pure function of `current_pick_number`, `size`, and `draft_order_style`;
  # encapsulates the Drafts::Order lookup so callers don't repeat it.
  def current_picker
    return nil if current_pick_number > total_picks
    pos = Drafts::Order.position_for(
      pick_number: current_pick_number,
      size: size,
      style: draft_order_style
    )
    participants.find_by(draft_position: pos)
  end

  def picks_per_participant
    season.season_teams.count / size
  end

  def total_picks
    picks_per_participant * size
  end

  private

  def assign_invite_code
    self.invite_code ||= self.class.generate_unique_invite_code
  end

  # Manual drafts have no clock and no scheduled start. Clearing on save
  # keeps stale "live"-mode values from sneaking through if the owner
  # switches the draft from live to manual.
  def normalize_for_draft_mode
    return unless manual_mode?
    self.pick_clock_seconds = nil
    self.draft_scheduled_at = nil
  end
end
