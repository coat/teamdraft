# frozen_string_literal: true

module Standings
  # Builds the per-participant standings for a league. For each participant,
  # we list their drafted teams (with point totals and event breakdowns)
  # and sum to a grand total. Sorted by total desc.
  class Calculate
    Row = Data.define(:participant, :total_points, :teams)
    TeamLine = Data.define(:season_team, :team, :pick_number, :autopicked, :points, :events)

    def self.call(...) = new(...).call

    def initialize(league_season:)
      @league_season = league_season
    end

    def call
      picks = @league_season.draft_picks.includes(:participant, season_team: [:team, :scoring_events]).to_a
      grouped = picks.group_by(&:participant)

      ordered_participants = @league_season.participants.to_a
      rows = ordered_participants.map do |participant|
        team_lines = (grouped[participant] || []).map { |pick| build_team_line(pick) }
          .sort_by { |line| -line.points }
        Row.new(
          participant:,
          total_points: team_lines.sum(&:points),
          teams: team_lines
        )
      end

      rows.sort_by { |row| [-row.total_points, row.participant.draft_position] }
    end

    private

    def build_team_line(pick)
      events = pick.season_team.scoring_events
      points = events.sum(&:points)
      breakdown = events.group_by(&:event_type).transform_values { |list| list.sum(&:points) }

      TeamLine.new(
        season_team: pick.season_team,
        team: pick.season_team.team,
        pick_number: pick.pick_number,
        autopicked: pick.autopicked,
        points:,
        events: breakdown
      )
    end
  end
end
