# frozen_string_literal: true

module Drafts
  # Picks the best remaining team for whoever is on the clock. Used by
  # PickClockJob when a participant times out. Ordering: lowest
  # default_pick_rank first, then alphabetical by team name as a tiebreaker
  # for unranked seasons.
  class AutoPick
    def self.call(...) = new(...).call

    def initialize(league_season:)
      @league_season = league_season
    end

    def call
      season_team = next_available_team
      return nil unless season_team
      SubmitPick.call(league_season: @league_season, season_team:, autopicked: true)
    end

    private

    def next_available_team
      drafted = @league_season.draft_picks.pluck(:season_team_id)
      @league_season.season.season_teams
        .joins(:team)
        .where.not(season_teams: {id: drafted})
        .order(Arel.sql("teams.default_pick_rank NULLS LAST, teams.name ASC"))
        .first
    end
  end
end
