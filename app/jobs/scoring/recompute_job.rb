# frozen_string_literal: true

module Scoring
  class RecomputeJob < ApplicationJob
    queue_as :default

    def perform(season_id)
      season = Season.find(season_id)
      Recompute.call(season:)
    end
  end
end
