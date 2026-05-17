# frozen_string_literal: true

module Seasons
  # Attaches a SeasonTeam for every Team in the season's sport. Idempotent
  # via SeasonTeam's (season_id, team_id) uniqueness, so it's safe to
  # re-run on a partially populated season.
  class PopulateTeams
    def self.call(...) = new(...).call

    def initialize(season:)
      @season = season
    end

    def call
      SeasonTeam.transaction do
        @season.sport.teams.find_each do |team|
          SeasonTeam.find_or_create_by!(season_id: @season.id, team_id: team.id)
        end
      end
      @season
    end
  end
end
