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

    SportConfig = Struct.new(:league_id, :regular_rounds, :playoff_rounds, :season_format) do
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
      # NBA: 2024-2025 and earlier put all regular-season games under
      # intRound="0" (verified via eventsround.php). Starting with
      # 2025-2026 the API switched to per-week numbering (rounds 1-26,
      # verified live on 2026-05-17). Round 0 in the new scheme maps to
      # NBA Cup / in-season tournament games. The free TheSportsDB tier
      # caps responses at 50 events per request; a regular-season sync
      # built only on eventsround will undercount for "0"-based seasons.
      # The proper long-term fix is to switch NBA regular-season ingestion
      # to eventsday.php.
      "nba" => SportConfig.new(
        league_id: "4387",
        regular_rounds: (0..26).map(&:to_s),
        playoff_rounds: {
          "400" => "play_in",
          "160" => "first_round",
          "125" => "conf_semis",
          "150" => "conf_finals",
          "180" => "finals"
        },
        season_format: ->(year) { "#{year}-#{year + 1}" }
      ),
      # MLB regular-season events all carry intRound="0" - there's no per-week
      # structure. On the free tier eventsday.php caps at ~3 events per call,
      # so date-based ingestion was infeasible; on the paid tier the cap
      # lifts and the recurring date-based sync (Sync::RefreshActiveSeasonsJob)
      # can pull a full day's slate. Listing "0" here lets parse_event label
      # those games as regular_season - the round-based "fetch all rounds"
      # path will also attempt r=0, which on paid tier returns the season
      # opener chunk and on free tier returns null (a no-op, not an error).
      # MLB happens to share NFL's playoff intRound encoding.
      "mlb" => SportConfig.new(
        league_id: "4424",
        regular_rounds: ["0"],
        playoff_rounds: {
          "160" => "wildcard",
          "125" => "division_series",
          "150" => "lcs",
          "200" => "world_series"
        },
        season_format: ->(year) { year.to_s }
      )
    }.freeze

    def initialize(season:, api_key: ENV.fetch("THESPORTSDB_KEY", DEFAULT_KEY), http: Net::HTTP)
      super(season:)
      @api_key = api_key
      @http = http
    end

    def fetch_games(rounds: nil, dates: nil)
      return fetch_games_by_date(dates) if dates
      rounds_to_fetch = rounds_to_fetch_for(rounds)
      rounds_to_fetch.flat_map do |round|
        payload = request("eventsround.php", id: sport_config.league_id, r: round, s: season_string)
        Array(payload["events"]).filter_map { |e| parse_event(e) }
      end
    end

    def round_numbers
      self.class.round_numbers_for(@season.sport.key)
    end

    def round_labels
      self.class.round_labels_for(@season.sport.key)
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

    def fetch_games_by_date(dates)
      Array(dates).flat_map do |date|
        payload = request("eventsday.php", d: date.to_s, l: sport_config.league_id)
        Array(payload["events"]).filter_map { |e| parse_event(e) }
      end
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
        starts_at: parse_start(event),
        round:,
        week: parsed_week_for(round, event["intRound"]),
        status: status_for(event)
      )
    end

    # Only NFL/NBA-style weekly rounds carry meaningful week numbers. MLB
    # tags every regular-season game as intRound=0; storing week=0 would be
    # misleading, so we keep it nil there.
    def parsed_week_for(round, int_round)
      return nil unless round == "regular_season"
      week = parse_int(int_round)
      (week && week > 0) ? week : nil
    end

    def round_for(int_round)
      return nil if int_round.blank?
      str = int_round.to_s
      return sport_config.playoff_rounds[str] if sport_config.playoff_rounds.key?(str)
      return "regular_season" if sport_config.regular_round?(str)
      nil
    end

    # Postponed/cancelled events come back with strStatus="Match Finished"
    # but blank scores, which then trips the Game model's "scores required
    # for final" validation. Require scores to be present before calling a
    # game final; everything else stays scheduled so the row still upserts.
    def status_for(event)
      home = event["intHomeScore"]
      away = event["intAwayScore"]
      return "final" if home.present? && away.present?
      "scheduled"
    end

    def parse_start(event)
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
