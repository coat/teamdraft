# frozen_string_literal: true

module Drafts
  # Picks the best remaining team for whoever is on the clock. Used by
  # PickClockJob when a participant times out. Ordering: the picking user's
  # personal ranking (if any) wins, then global default_pick_rank, then
  # alphabetical by team name as a final tiebreaker.
  class AutoPick
    def self.call(...) = new(...).call

    def initialize(league_season:, expected_pick_number: nil)
      @league_season = league_season
      @expected_pick_number = expected_pick_number
    end

    def call
      season_team = next_available_team
      return nil unless season_team
      SubmitPick.call(league_season: @league_season, season_team:, autopicked: true,
        expected_pick_number: @expected_pick_number)
    end

    private

    def next_available_team
      drafted = @league_season.draft_picks.pluck(:season_team_id)
      rel = @league_season.season.season_teams
        .joins(:team)
        .where.not(season_teams: {id: drafted})

      user_id = current_participant&.user_id
      if user_id
        sport_id = @league_season.season.sport_id
        join_sql = ActiveRecord::Base.sanitize_sql_array([
          "LEFT OUTER JOIN user_team_rankings utr " \
          "ON utr.team_id = teams.id AND utr.user_id = ? AND utr.sport_id = ?",
          user_id, sport_id
        ])
        rel.joins(join_sql)
          .order(Arel.sql("utr.rank ASC NULLS LAST, teams.default_pick_rank ASC NULLS LAST, teams.name ASC"))
          .first
      else
        rel.order(Arel.sql("teams.default_pick_rank NULLS LAST, teams.name ASC")).first
      end
    end

    def current_participant
      pos = Drafts::Order.position_for(
        pick_number: @league_season.current_pick_number,
        size: @league_season.size,
        style: @league_season.draft_order_style
      )
      @league_season.participants.find_by(draft_position: pos)
    end
  end
end
