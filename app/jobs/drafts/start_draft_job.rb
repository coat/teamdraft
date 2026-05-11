# frozen_string_literal: true

module Drafts
  # Fired at draft_scheduled_at to flip a ready league into "drafting".
  # Idempotent — StartIfReady no-ops when the league is already drafting,
  # missing seats, etc.
  class StartDraftJob < ApplicationJob
    queue_as :default

    def perform(league_id)
      league = League.find(league_id)
      Drafts::StartIfReady.call(league:)
    end
  end
end
