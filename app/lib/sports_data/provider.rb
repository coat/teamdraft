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

    private

    # Shared by the JSON API providers. HTTPX does not raise on
    # connection-level failures (DNS, TLS, timeouts) - it returns an
    # HTTPX::ErrorResponse, which has no #status - so that case must be
    # checked before anything else. `label` names the endpoint in error
    # messages (e.g. "schedule returned 503").
    def get_json(url, headers:, label: "request")
      response = HTTPX.with(headers:).get(url)
      raise FetchFailed, "request failed: #{response.error.message}" if response.is_a?(HTTPX::ErrorResponse)
      raise FetchFailed, "rate limited - retry after 60s" if response.status == 429
      raise FetchFailed, "#{label} returned #{response.status}" unless response.status.between?(200, 299)
      JSON.parse(response.body.to_s)
    rescue HTTPX::Error => e
      raise FetchFailed, "request failed: #{e.message}"
    rescue JSON::ParserError => e
      raise FetchFailed, "invalid JSON from #{label}: #{e.message}"
    end

    # Shared by the JSON API providers (MLB Stats API, Moneyline, NBA),
    # which all expose start times as ISO8601 strings.
    def parse_start(value)
      return nil if value.blank?
      Time.iso8601(value)
    rescue ArgumentError
      nil
    end
  end
end
