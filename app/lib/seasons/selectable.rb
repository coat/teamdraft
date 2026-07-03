# frozen_string_literal: true

module Seasons
  # Seasons offered in the league-creation dropdown: upcoming first (soonest
  # first), then active / in-progress (most-recently-started first).
  # Only the earliest upcoming season per sport is shown so future pre-created
  # seasons don't clutter the dropdown.
  class Selectable
    def self.call = new.call

    # Fallback when no season was chosen on the form (e.g. first render).
    # Prefer the soonest upcoming season, falling back to the most-recently-started active.
    def self.default
      seasons = call
      seasons.where(status: "upcoming").first || seasons.first
    end

    def call
      Season.where(status: %w[upcoming active])
        .includes(:sport).joins(:sport)
        .where(
          "seasons.status = 'active' OR seasons.id IN (" \
          "SELECT DISTINCT ON (sport_id) s.id FROM seasons s " \
          "WHERE s.status = 'upcoming' ORDER BY s.sport_id, s.starts_on ASC" \
          ")"
        )
        .order(
          Arel.sql("CASE WHEN seasons.status = 'upcoming' THEN 0 ELSE 1 END"),
          Arel.sql("CASE WHEN seasons.status = 'upcoming' THEN seasons.starts_on END ASC"),
          Arel.sql("CASE WHEN seasons.status = 'active' THEN seasons.starts_on END DESC"),
          "sports.name"
        )
    end
  end
end
