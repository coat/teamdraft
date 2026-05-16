# frozen_string_literal: true

module Drafts
  # Fired at draft_scheduled_at to flip a ready league season into "drafting".
  # Idempotent — StartIfReady no-ops when the league season is already
  # drafting, missing seats, etc.
  class StartDraftJob < ApplicationJob
    queue_as :default

    def perform(league_season_id)
      ls = LeagueSeason.find(league_season_id)
      Drafts::StartIfReady.call(league_season: ls)
    end
  end
end
