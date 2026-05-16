# frozen_string_literal: true

class League < ApplicationRecord
  extend FriendlyId

  friendly_id :name, use: [:slugged, :history], slug_column: :slug

  broadcasts_refreshes

  has_many :league_seasons, dependent: :destroy, inverse_of: :league
  has_many :participants, through: :league_seasons
  has_many :draft_picks, through: :league_seasons

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: {case_sensitive: false}

  # The league's "current" per-season run. Prefer the LeagueSeason tied to
  # the sport's active Season; otherwise fall back to the most-recent one.
  def current_league_season
    @current_league_season ||=
      league_seasons.joins(:season).where(seasons: {status: "active"}).order("seasons.year DESC").first ||
      league_seasons.joins(:season).order("seasons.year DESC").first
  end

  # Convenience: the owner participant in the current LeagueSeason.
  def owner
    current_league_season&.owner
  end

  # Transient form-only accessors. The "Create league" form (`Views::Leagues::Form`)
  # binds these to `form_with(model: @league)` so a fresh League returned from
  # the controller can carry default values, but they are not persisted — the
  # controller forwards them into `Leagues::Create`, which writes them to the
  # initial `LeagueSeason`.
  attr_accessor :your_name, :opponent_name,
    :draft_mode, :draft_scheduled_at, :pick_clock_seconds

  def normalize_friendly_id(value)
    "#{value.to_s.parameterize.presence || "league"}-#{rand(1000..9999)}"
  end

  def should_generate_new_friendly_id?
    name_changed? || super
  end
end
