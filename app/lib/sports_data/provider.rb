# frozen_string_literal: true

module SportsData
  # Interface for external sports data providers. Concrete providers
  # (e.g. TheSportsDbProvider) implement #fetch_games returning an
  # Enumerable of SportsData::ParsedGame.
  class Provider
    PROVIDERS = {
      "thesportsdb" => "SportsData::TheSportsDbProvider",
      "mlb_stats_api" => "SportsData::MlbStatsApiProvider",
      "nba_stats_api" => "SportsData::NbaStatsApiProvider",
      "moneyline" => "SportsData::MoneylineProvider"
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

    def fetch_games(rounds: nil, dates: nil)
      raise NotImplementedError
    end

    # Valid round keys (strings) the admin UI may pass via `rounds:`. Each
    # concrete provider chooses its own encoding (TheSportsDB uses intRound
    # codes like "1", "200"; MLB Stats API uses gameType codes like "R",
    # "W"). The shape is opaque to the controller - values flow back
    # through fetch_games(rounds: …).
    def round_numbers
      raise NotImplementedError
    end

    # Map from round key to human-readable label, used in the admin sync
    # form dropdown.
    def round_labels
      raise NotImplementedError
    end
  end
end
