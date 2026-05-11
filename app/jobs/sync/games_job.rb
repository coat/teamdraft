# frozen_string_literal: true

module Sync
  class GamesJob < ApplicationJob
    queue_as :default

    def perform(season_id)
      season = Season.find(season_id)
      provider = SportsData::Provider.for(season)
      parsed = provider.fetch_games
      result = ApplyGames.call(season:, parsed_games: parsed)

      Rails.logger.info("[sync] season=#{season.id} upserted=#{result.upserted} skipped=#{result.skipped} final=#{result.final_count}")

      Scoring::RecomputeJob.perform_later(season.id) if result.final_count.positive?
      result
    end
  end
end
