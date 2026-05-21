# frozen_string_literal: true

module Seasons
  # Per-team standings for a season: regular-season and playoff W-L-T from
  # final Game records, plus default-scoring points using the sport's base
  # ScoringRule values (no league-specific overrides). Rows are ordered by
  # default points DESC, then regular-season wins DESC.
  class TeamStandings
    Row = Data.define(:season_team, :team, :reg_w, :reg_l, :reg_t, :po_w, :po_l, :po_t, :points)

    def self.call(...) = new(...).call

    def initialize(season:)
      @season = season
    end

    def call
      rules = Scoring::Rules.for(@season.sport)
      season_teams = @season.season_teams.includes(:team, :scoring_events, :home_games, :away_games)

      rows = season_teams.map { |st| build_row(st, rules) }
      rows.sort_by { |r| [-r.points, -r.po_w, -r.reg_w, r.team.name] }
    end

    private

    def build_row(season_team, rules)
      reg_w = reg_l = reg_t = 0
      po_w = po_l = po_t = 0

      [[season_team.home_games, :home], [season_team.away_games, :away]].each do |games, side|
        games.each do |g|
          next unless g.status == "final" && g.home_score && g.away_score

          own, opp = (side == :home) ? [g.home_score, g.away_score] : [g.away_score, g.home_score]
          outcome = (own <=> opp)

          if g.round == Game::REGULAR_SEASON
            case outcome
            when 1 then reg_w += 1
            when -1 then reg_l += 1
            else reg_t += 1
            end
          else
            case outcome
            when 1 then po_w += 1
            when -1 then po_l += 1
            else po_t += 1
            end
          end
        end
      end

      points = season_team.scoring_events.sum { |e| rules.points_for(e.event_type) }

      Row.new(
        season_team: season_team,
        team: season_team.team,
        reg_w: reg_w, reg_l: reg_l, reg_t: reg_t,
        po_w: po_w, po_l: po_l, po_t: po_t,
        points: points
      )
    end
  end
end
