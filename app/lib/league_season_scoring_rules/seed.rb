# frozen_string_literal: true

module LeagueSeasonScoringRules
  # Copies the sport's ScoringRule point values onto a LeagueSeason as
  # LeagueSeasonScoringRule rows. Idempotent: skips rules that already have an
  # override. With `reset: true`, overwrites existing overrides back to the
  # sport defaults — used by the "Reset to sport defaults" button.
  #
  # Called whenever a LeagueSeason is created (see Leagues::Create) and
  # invoked by the backfill migration via the same model so behavior stays
  # consistent.
  class Seed
    def self.call(...) = new(...).call

    def initialize(league_season, reset: false)
      @league_season = league_season
      @reset = reset
    end

    def call
      sport = @league_season.season.sport
      existing = LeagueSeasonScoringRule.where(league_season_id: @league_season.id).index_by(&:scoring_rule_id)

      ApplicationRecord.transaction do
        sport.scoring_rules.ordered.each do |rule|
          override = existing[rule.id]
          if override.nil?
            @league_season.scoring_rule_overrides.create!(
              scoring_rule: rule,
              points: rule.points
            )
          elsif @reset
            override.update!(points: rule.points)
          end
        end
      end
    end
  end
end
