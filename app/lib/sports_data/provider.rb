# frozen_string_literal: true

module SportsData
  # Interface for external sports data providers. Concrete providers
  # (e.g. TheSportsDbProvider) implement #fetch_games returning an
  # Enumerable of SportsData::ParsedGame.
  class Provider
    PROVIDERS = {
      "thesportsdb" => "SportsData::TheSportsDbProvider"
    }.freeze

    def self.for(season)
      key = season.external_provider.presence || "thesportsdb"
      class_name = PROVIDERS.fetch(key) { raise UnknownProvider, "no provider registered for #{key.inspect}" }
      class_name.constantize.new(season:)
    end

    class UnknownProvider < StandardError; end
    class FetchFailed < StandardError; end

    def initialize(season:)
      @season = season
    end

    def fetch_games(since: nil)
      raise NotImplementedError
    end
  end
end
