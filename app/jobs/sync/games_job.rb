# frozen_string_literal: true

module Sync
  class GamesJob < ApplicationJob
    queue_as :default

    def perform(season_id, rounds: nil, dates: nil)
      season = Season.find(season_id)
      provider = SportsData::Provider.for(season)
      parsed = provider.fetch_games(rounds: rounds, dates: dates)
      result = ApplyGames.call(season:, parsed_games: parsed)

      # Stamped only on the success path so a transient API failure doesn't
      # suppress the 3h overnight fallback in RefreshActiveSeasonsJob.
      season.update_column(:last_synced_at, Time.current)

      Rails.logger.info("[sync] season=#{season.id} upserted=#{result.upserted} skipped=#{result.skipped} final=#{result.final_count}")

      Scoring::RecomputeJob.perform_later(season.id) if result.final_count.positive?
      result
    end
  end
end
