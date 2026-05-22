# frozen_string_literal: true

module Scoring
  # Walks every final game in a season and upserts ScoringEvent rows. The
  # (season_team_id, game_id, event_type) unique index makes this idempotent:
  # repeated calls converge on the same set of events without duplicates.
  #
  # Scoring shape is driven entirely by the season's sport's scoring_rules:
  #   - regular season: each game winner gets one regular_win event.
  #   - playoffs: each *participant* of a playoff game gets the appearance
  #     event for that round (if the sport defines one). Points stack as a
  #     team advances.
  #   - championship: the winner additionally gets the championship_win event.
  #   - bye backfill: if a sport flags a playoff rule with bye_backfill=true
  #     (e.g. NFL's playoff_appearance), participants in the round immediately
  #     after pick up that appearance event if they didn't already have one.
  class Recompute
    def self.call(...) = new(...).call

    def initialize(season:)
      @season = season
      @rules = Rules.for(season.sport)
    end

    def call
      ApplicationRecord.transaction do
        @season.games.final.includes(:home_season_team, :away_season_team).find_each do |game|
          if game.round == Game::REGULAR_SEASON
            score_regular_season(game)
          else
            score_playoff_game(game)
          end
        end
        apply_default_pick_ranks
      end
    end

    private

    # Re-derive Team.default_pick_rank for every team in this season's sport
    # from the points just upserted above. Season participants come first,
    # ordered by total default points DESC, then team name ASC. Teams in the
    # sport but not in this season come after, ordered by name ASC, so they
    # keep a deterministic rank for any other league using this sport.
    def apply_default_pick_ranks
      sport = @season.sport

      participant_rows = @season.season_teams.includes(:team, :scoring_events).map do |st|
        total = st.scoring_events.sum { |e| @rules.points_for(e.event_type) }
        [st.team, total]
      end
      participant_ids = participant_rows
        .sort_by { |team, total| [-total, team.name] }
        .map { |team, _| team.id }

      participant_id_set = participant_ids.to_set
      non_participant_ids = sport.teams
        .where.not(id: participant_id_set.to_a)
        .order(:name)
        .pluck(:id)

      ordered_ids = participant_ids + non_participant_ids

      Team.where(sport_id: sport.id).update_all(default_pick_rank: nil)
      ordered_ids.each_with_index do |team_id, idx|
        Team.where(id: team_id).update_all(default_pick_rank: idx + 1)
      end
    end

    def score_regular_season(game)
      event_type = @rules.regular_win_event
      return unless event_type
      winner = game.winner_season_team
      return unless winner
      upsert_event(
        season_team: winner,
        game:,
        event_type:,
        occurred_at: occurred_at(game)
      )
    end

    def score_playoff_game(game)
      appearance = @rules.appearance_event_for_round(game.round)
      occurred = occurred_at(game)

      if appearance
        game.participants.compact.each do |season_team|
          upsert_event(season_team:, game:, event_type: appearance, occurred_at: occurred)
          backfill_bye(season_team, game, occurred)
        end
      end

      championship_event = @rules.championship_win_event
      return unless championship_event && game.round == championship_round_key

      winner = game.winner_season_team
      return unless winner
      upsert_event(
        season_team: winner, game:,
        event_type: championship_event,
        occurred_at: occurred
      )
    end

    def backfill_bye(season_team, game, occurred)
      rule = @rules.bye_backfill_rule
      return unless rule
      return unless game.round == @rules.bye_backfill_trigger_round
      return if has_event?(season_team, rule.event_type)
      upsert_event(
        season_team:, game:,
        event_type: rule.event_type,
        occurred_at: occurred
      )
    end

    # The final playoff round for the sport - whichever round_key the
    # championship_win event is paired with. We infer it by finding the
    # last-display_order playoff_appearance rule.
    def championship_round_key
      @championship_round_key ||= @season.sport.scoring_rules.ordered
        .where(kind: "playoff_appearance")
        .last&.round_key
    end

    def has_event?(season_team, event_type)
      ScoringEvent
        .where(season_team_id: season_team.id, event_type: event_type)
        .joins(:game).where(games: {season_id: @season.id})
        .exists?
    end

    def occurred_at(game)
      game.completed_at || game.kickoff_at
    end

    def upsert_event(season_team:, game:, event_type:, occurred_at:)
      ScoringEvent.upsert(
        {
          season_team_id: season_team.id,
          game_id: game.id,
          event_type:,
          occurred_at:,
          created_at: Time.current,
          updated_at: Time.current
        },
        unique_by: :index_scoring_events_unique_per_team_game_type
      )
    end
  end
end
