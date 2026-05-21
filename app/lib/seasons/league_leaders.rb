# frozen_string_literal: true

module Seasons
  # Per-public-league summary for a season: the top participant + their score,
  # plus seat counts. Rows are ordered by top_score DESC. Uses each league's
  # own scoring overrides via Standings::Calculate.
  class LeagueLeaders
    Row = Data.define(:league_season, :top_participant, :top_score, :filled_seats, :total_seats)

    def self.call(...) = new(...).call

    def initialize(season:)
      @season = season
    end

    def call
      league_seasons = @season.league_seasons
        .joins(:league).where(leagues: {private: false})
        .includes(:league, participants: :user)

      rows = league_seasons.map do |ls|
        standings = Standings::Calculate.call(league_season: ls)
        top = standings.first
        Row.new(
          league_season: ls,
          top_participant: top&.participant,
          top_score: top&.total_points || 0,
          filled_seats: ls.participants.size,
          total_seats: ls.size
        )
      end

      rows.sort_by { |r| [-r.top_score, r.league_season.league.name] }
    end
  end
end
