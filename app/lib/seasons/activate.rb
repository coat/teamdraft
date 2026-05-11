# frozen_string_literal: true

module Seasons
  # Marks one season `active` and demotes any other currently-active season
  # for the same sport to `completed`, so the "one active season per sport"
  # invariant is automatic instead of relying on the admin to remember.
  class Activate
    def self.call(...) = new(...).call

    def initialize(season:)
      @season = season
    end

    def call
      Season.transaction do
        Season.where(sport_id: @season.sport_id, status: "active")
          .where.not(id: @season.id)
          .update_all(status: "completed", updated_at: Time.current)
        @season.update!(status: "active")
      end
      @season
    end
  end
end
