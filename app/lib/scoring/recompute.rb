# frozen_string_literal: true

module Scoring
  # Walks every final game in a season and upserts ScoringEvent rows. The
  # (season_team_id, game_id, event_type) unique index makes this idempotent:
  # repeated calls converge on the same set of events without duplicates.
  #
  # Scoring shape (NFL default):
  #   - regular season: each game winner gets one regular_win event.
  #   - playoffs: each *participant* of a playoff game gets the corresponding
  #     appearance event (playoff/divisional/conference/championship). Points
  #     stack as a team advances. Bye teams pick up playoff_appearance via
  #     their divisional game (no wildcard game exists for them).
  #   - championship: the winner additionally gets championship_win.
  class Recompute
    def self.call(...) = new(...).call

    def initialize(season:)
      @season = season
      @rules = Rules.for(season.sport)
    end

    def call
      ApplicationRecord.transaction do
        @season.games.final.includes(:home_season_team, :away_season_team).find_each do |game|
          if game.round == "regular_season"
            score_regular_season(game)
          else
            score_playoff_game(game)
          end
        end
      end
    end

    private

    def score_regular_season(game)
      winner = game.winner_season_team
      return unless winner
      upsert_event(
        season_team: winner,
        game:,
        event_type: "regular_win",
        points: @rules.points_for("regular_win"),
        occurred_at: occurred_at(game)
      )
    end

    def score_playoff_game(game)
      appearance = @rules.appearance_event_for_round(game.round)
      points = @rules.points_for(appearance)
      occurred = occurred_at(game)

      game.participants.compact.each do |season_team|
        upsert_event(season_team:, game:, event_type: appearance, points:, occurred_at: occurred) if points.positive?

        # Bye teams skip the wildcard round but still "made the playoffs" —
        # credit them via their divisional game if no earlier playoff
        # appearance event exists yet for the season.
        if game.round == "divisional" && !has_playoff_appearance?(season_team)
          upsert_event(
            season_team:, game:,
            event_type: "playoff_appearance",
            points: @rules.points_for("playoff_appearance"),
            occurred_at: occurred
          )
        end
      end

      if game.round == "championship"
        winner = game.winner_season_team
        if winner && @rules.points_for("championship_win").positive?
          upsert_event(
            season_team: winner, game:,
            event_type: "championship_win",
            points: @rules.points_for("championship_win"),
            occurred_at: occurred
          )
        end
      end
    end

    def has_playoff_appearance?(season_team)
      ScoringEvent
        .where(season_team_id: season_team.id, event_type: "playoff_appearance")
        .joins(:game).where(games: {season_id: @season.id})
        .exists?
    end

    def occurred_at(game)
      game.completed_at || game.kickoff_at
    end

    def upsert_event(season_team:, game:, event_type:, points:, occurred_at:)
      ScoringEvent.upsert(
        {
          season_team_id: season_team.id,
          game_id: game.id,
          event_type:,
          points:,
          occurred_at:,
          created_at: Time.current,
          updated_at: Time.current
        },
        unique_by: :index_scoring_events_unique_per_team_game_type
      )
    end
  end
end
