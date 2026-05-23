# frozen_string_literal: true

module Leagues
  # Creates a new league plus its initial LeagueSeason and two participants
  # (you + opponent), generating a haikunator slug. Returns [league, owner].
  # Transactional.
  class Create
    def self.call(...) = new(...).call

    def initialize(your_name:, opponent_name:, season:, name: nil, draft_scheduled_at: nil,
      draft_mode: "live", pick_clock_seconds: nil, owner_user: nil)
      @your_name = your_name.to_s.strip
      @opponent_name = opponent_name.to_s.strip
      @season = season
      @name = name.presence || "#{@your_name} vs #{@opponent_name}"
      @draft_scheduled_at = draft_scheduled_at
      @draft_mode = (LeagueSeason::DRAFT_MODES.include?(draft_mode.to_s) ? draft_mode.to_s : "live")
      @pick_clock_seconds = resolve_pick_clock(pick_clock_seconds)
      @owner_user = owner_user
    end

    def call
      ApplicationRecord.transaction do
        league = build_league
        league.save!
        league_season = league.league_seasons.create!(
          season: @season,
          size: 2,
          draft_mode: @draft_mode,
          draft_order_style: "linear",
          draft_scheduled_at: @draft_scheduled_at,
          pick_clock_seconds: @pick_clock_seconds
        )
        LeagueSeasonScoringRules::Seed.call(league_season)
        owner = league_season.participants.create!(
          display_name: @your_name,
          draft_position: 1,
          is_owner: true,
          joined_at: Time.current,
          user: @owner_user
        )
        league_season.participants.create!(
          display_name: @opponent_name,
          draft_position: 2,
          is_owner: false,
          invited_at: Time.current
        )
        Drafts::StartIfReady.call(league_season: league_season)
        [league, owner]
      end
    end

    private

    # Live drafts need a clock for the auto-pick job to fire on a schedule;
    # default to LeagueSeason::DEFAULT_PICK_CLOCK_SECONDS when the caller
    # doesn't specify one. Manual drafts stay clockless — the LeagueSeason
    # `before_validation` also nils any stray clock value defensively.
    def resolve_pick_clock(value)
      return nil unless @draft_mode == "live"
      value.presence&.to_i || LeagueSeason::DEFAULT_PICK_CLOCK_SECONDS
    end

    def build_league
      League.new(name: @name)
    end
  end
end
