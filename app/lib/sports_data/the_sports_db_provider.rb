# frozen_string_literal: true

require "net/http"
require "json"

module SportsData
  # TheSportsDB v1 JSON API. Free tier uses API key "123" (rate-limited).
  # https://www.thesportsdb.com/free_api.php
  #
  # Each supported sport supplies its TheSportsDB league id, the set of
  # regular-season "intRound" values to fetch, a map of playoff intRound
  # codes to our generic round_key strings, and a lambda that formats the
  # season's year into TheSportsDB's `strSeason` (NFL uses "2025", NBA uses
  # "2025-2026", etc.).
  class TheSportsDbProvider < Provider
    BASE_URL = "https://www.thesportsdb.com/api/v1/json"
    DEFAULT_KEY = "123"

    SportConfig = Struct.new(:league_id, :regular_rounds, :playoff_rounds, :season_format, keyword_init: true) do
      def all_rounds
        regular_rounds + playoff_rounds.keys
      end

      def regular_round?(int_round)
        regular_rounds.include?(int_round.to_s)
      end
    end

    SPORT_CONFIG = {
      "nfl" => SportConfig.new(
        league_id: "4391",
        regular_rounds: (1..18).map(&:to_s),
        playoff_rounds: {
          "160" => "wildcard",
          "125" => "divisional",
          "150" => "conference",
          "200" => "championship"
        },
        season_format: ->(year) { year.to_s }
      ),
      # NBA: regular-season games are returned under intRound="0" (verified
      # against 2024-2025 via eventsround.php). The free TheSportsDB tier
      # caps that response at 50 events per request, so a regular-season
      # sync built only on eventsround will undercount; the proper fix is
      # to switch NBA regular-season ingestion to eventsday.php in a future
      # iteration. Playoff codes were verified live on 2026-05-17.
      "nba" => SportConfig.new(
        league_id: "4387",
        regular_rounds: ["0"],
        playoff_rounds: {
          "400" => "play_in",
          "160" => "first_round",
          "125" => "conf_semis",
          "150" => "conf_finals",
          "180" => "finals"
        },
        season_format: ->(year) { "#{year}-#{year + 1}" }
      )
    }.freeze

    def initialize(season:, api_key: ENV.fetch("THESPORTSDB_KEY", DEFAULT_KEY), http: Net::HTTP)
      super(season:)
      @api_key = api_key
      @http = http
    end

    def fetch_games(rounds: nil)
      rounds_to_fetch = rounds_to_fetch_for(rounds)
      rounds_to_fetch.flat_map do |round|
        payload = request("eventsround.php", id: sport_config.league_id, r: round, s: season_string)
        Array(payload["events"]).filter_map { |e| parse_event(e) }
      end
    end

    def self.round_numbers_for(sport_key)
      cfg = SPORT_CONFIG.fetch(sport_key) { return [] }
      cfg.all_rounds
    end

    def self.round_labels_for(sport_key)
      cfg = SPORT_CONFIG.fetch(sport_key) { return {} }
      labels = cfg.regular_rounds.each_with_object({}) { |n, h| h[n] = "Week #{n}" }
      cfg.playoff_rounds.each { |code, key| labels[code] = key.tr("_", " ").split.map(&:capitalize).join(" ") }
      labels
    end

    private

    def sport_config
      SPORT_CONFIG.fetch(@season.sport.key) {
        raise FetchFailed, "no TheSportsDB config mapped for sport #{@season.sport.key.inspect}"
      }
    end

    def rounds_to_fetch_for(rounds)
      return sport_config.all_rounds if rounds.nil?
      requested = Array(rounds).map(&:to_s)
      unknown = requested - sport_config.all_rounds
      raise FetchFailed, "unknown round(s): #{unknown.inspect}" if unknown.any?
      requested
    end

    def season_string
      sport_config.season_format.call(@season.year)
    end

    def request(path, **params)
      uri = URI("#{BASE_URL}/#{@api_key}/#{path}")
      uri.query = URI.encode_www_form(params)
      response = @http.get_response(uri)
      raise FetchFailed, "#{path} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise FetchFailed, "invalid JSON from #{path}: #{e.message}"
    end

    def parse_event(event)
      round = round_for(event["intRound"])
      return nil unless round

      ParsedGame.new(
        external_id: event["idEvent"],
        home_team_external_id: event["idHomeTeam"],
        away_team_external_id: event["idAwayTeam"],
        home_score: parse_int(event["intHomeScore"]),
        away_score: parse_int(event["intAwayScore"]),
        kickoff_at: parse_kickoff(event),
        round:,
        week: (round == "regular_season") ? Integer(event["intRound"]) : nil,
        status: status_for(event)
      )
    end

    def round_for(int_round)
      return nil if int_round.blank?
      str = int_round.to_s
      return sport_config.playoff_rounds[str] if sport_config.playoff_rounds.key?(str)
      return "regular_season" if sport_config.regular_round?(str)
      nil
    end

    def status_for(event)
      home = event["intHomeScore"]
      away = event["intAwayScore"]
      if event["strStatus"] == "Match Finished" || (home.present? && away.present?)
        "final"
      else
        "scheduled"
      end
    end

    def parse_kickoff(event)
      date = event["dateEvent"]
      time = event["strTime"].presence || "00:00:00"
      Time.parse("#{date} #{time} UTC")
    rescue ArgumentError, TypeError
      nil
    end

    def parse_int(value)
      return nil if value.nil? || value == ""
      Integer(value)
    rescue ArgumentError
      nil
    end
  end
end
