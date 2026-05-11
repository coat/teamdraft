# frozen_string_literal: true

module Sync
  # Persists a batch of SportsData::ParsedGame into the games table for a
  # season. Games whose teams can't be resolved (because team external_ids
  # haven't been mapped yet) are skipped — we don't want a partial sync to
  # raise mid-batch and lose progress.
  class ApplyGames
    Result = Data.define(:upserted, :skipped, :final_count)

    def self.call(...) = new(...).call

    def initialize(season:, parsed_games:)
      @season = season
      @parsed_games = parsed_games
    end

    def call
      upserted = 0
      skipped = 0
      final_count = 0

      ApplicationRecord.transaction do
        team_lookup = build_team_lookup

        @parsed_games.each do |pg|
          home = team_lookup[pg.home_team_external_id]
          away = team_lookup[pg.away_team_external_id]

          if home.nil? || away.nil?
            skipped += 1
            Rails.logger.info("[sync] skipping #{pg.external_id}: unmapped team(s)")
            next
          end

          game = upsert_game(pg, home, away)
          upserted += 1
          final_count += 1 if game.final?
        end
      end

      Result.new(upserted:, skipped:, final_count:)
    end

    private

    # Map team_external_id => SeasonTeam for this season, in one query.
    def build_team_lookup
      @season.season_teams.includes(:team).each_with_object({}) do |st, h|
        h[st.team.external_id] = st if st.team.external_id.present?
      end
    end

    def upsert_game(pg, home, away)
      game = @season.games.find_or_initialize_by(external_id: pg.external_id)
      game.assign_attributes(
        home_season_team: home,
        away_season_team: away,
        kickoff_at: pg.kickoff_at,
        round: pg.round,
        week: pg.week,
        home_score: pg.home_score,
        away_score: pg.away_score,
        status: pg.status,
        completed_at: (pg.status == "final") ? (game.completed_at || Time.current) : nil
      )
      game.save!
      game
    end
  end
end
