# frozen_string_literal: true

module Sync
  # Persists a batch of SportsData::ParsedGame into the games table for a
  # season. Games whose teams can't be resolved (because team external_ids
  # haven't been mapped yet) are skipped - we don't want a partial sync to
  # raise mid-batch and lose progress.
  #
  # Matching is two-tier: exact external_id first, then matchup fallback
  # (same home/away teams, starts_at within FALLBACK_WINDOW). The fallback
  # absorbs external_id changes - a provider switch (MLB Stats API gamePk ->
  # Moneyline eventId) or Moneyline's stub->real event transition - by
  # updating the existing row in place and adopting the new external_id
  # instead of inserting a duplicate.
  class ApplyGames
    Result = Data.define(:upserted, :skipped, :final_count)

    # Wide enough to absorb start-time drift between providers (and stub
    # events' approximate times), narrow enough to never reach a different
    # calendar day's game. Doubleheaders stay distinct via nearest-starts_at
    # matching with one claim per batch.
    FALLBACK_WINDOW = 12.hours

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

        mapped = @parsed_games.filter_map do |pg|
          home = team_lookup[pg.home_team_external_id]
          away = team_lookup[pg.away_team_external_id]

          if home.nil? || away.nil?
            skipped += 1
            Rails.logger.info("[sync] skipping #{pg.external_id}: unmapped team(s)")
            next
          end

          [pg, home, away]
        end

        matches = match_games(mapped)

        mapped.each do |pg, home, away|
          game = upsert_game(matches[pg], pg, home, away)
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

    # Resolve every event in the batch to its DB row (or nil for a new
    # game) before writing anything. Exact external_id matches claim their
    # rows first so a fallback match can never steal a row that another
    # event in the batch owns; each row is claimed at most once per batch.
    def match_games(mapped)
      matches = {}
      claimed = Set.new
      needs_fallback = []

      mapped.each do |pg, _home, _away|
        game = @season.games.find_by(external_id: pg.external_id)
        if game
          matches[pg] = game
          claimed << game.id
        else
          needs_fallback << pg
        end
      end

      mapped.each do |pg, home, away|
        next unless needs_fallback.include?(pg)
        game = fallback_match(pg, home, away, claimed)
        next unless game
        matches[pg] = game
        claimed << game.id
      end

      matches
    end

    def fallback_match(pg, home, away, claimed)
      return nil if pg.starts_at.nil?

      window = (pg.starts_at - FALLBACK_WINDOW)..(pg.starts_at + FALLBACK_WINDOW)
      @season.games
        .where(home_season_team: home, away_season_team: away, starts_at: window)
        .where.not(id: claimed.to_a)
        .min_by { |g| (g.starts_at - pg.starts_at).abs }
    end

    def upsert_game(game, pg, home, away)
      game ||= @season.games.build
      game.assign_attributes(
        external_id: pg.external_id,
        home_season_team: home,
        away_season_team: away,
        starts_at: pg.starts_at,
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
