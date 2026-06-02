# frozen_string_literal: true

require "net/http"
require "json"

module SportsData
  # MLB's public Stats API (https://statsapi.mlb.com/api/v1/). No API key,
  # no auth, no documented pagination cap on /schedule. We use it as the
  # MLB-only provider because TheSportsDB's free tier can't return a full
  # 162-game slate. mlb-rs/mlbt's `mlbt-api` crate confirmed the same
  # endpoints work without authentication.
  #
  # Round encoding here matches MLB's `gameType` codes; round_labels turns
  # them into human strings for the admin dropdown:
  #   R = Regular Season, F = Wild Card, D = Division Series,
  #   L = LCS, W = World Series
  #
  # The round_key strings exposed on ParsedGame (regular_season, wildcard,
  # division_series, lcs, world_series) match the existing MLB scoring
  # rules in lib/sports/configs/mlb.rb.
  class MlbStatsApiProvider < Provider
    BASE_URL = "https://statsapi.mlb.com/api/v1"
    SPORT_ID = 1
    USER_AGENT = "Mozilla/5.0 (compatible; teamdraft/1.0)"

    GAME_TYPE_TO_ROUND = {
      "R" => "regular_season",
      "F" => "wildcard",
      "D" => "division_series",
      "L" => "lcs",
      "W" => "world_series"
    }.freeze

    ROUND_LABELS = {
      "R" => "Regular Season",
      "F" => "Wild Card",
      "D" => "Division Series",
      "L" => "LCS",
      "W" => "World Series"
    }.freeze

    ALL_GAME_TYPES = GAME_TYPE_TO_ROUND.keys.freeze

    def initialize(season:, http: Net::HTTP)
      super(season:)
      @http = http
    end

    def fetch_games(rounds: nil, dates: nil)
      return fetch_games_by_dates(dates) if dates
      game_types = game_types_for(rounds)
      payload = request_schedule(season: season_year, gameTypes: game_types.join(","))
      parse_payload(payload)
    end

    def round_numbers
      ALL_GAME_TYPES.dup
    end

    def round_labels
      ROUND_LABELS.dup
    end

    private

    # Callers pass a contiguous list of dates (Sync::RefreshActiveSeasonsJob
    # sends yesterday+today; the admin date-range form sends every date in
    # the range). One /schedule call with min..max covers them all.
    def fetch_games_by_dates(dates)
      list = Array(dates).map(&:to_s).sort
      return [] if list.empty?
      payload = request_schedule(
        startDate: list.first,
        endDate: list.last,
        gameTypes: ALL_GAME_TYPES.join(",")
      )
      parse_payload(payload)
    end

    def game_types_for(rounds)
      return ALL_GAME_TYPES if rounds.nil?
      requested = Array(rounds).map(&:to_s)
      unknown = requested - ALL_GAME_TYPES
      raise FetchFailed, "unknown round(s): #{unknown.inspect}" if unknown.any?
      requested
    end

    def season_year
      @season.year.to_s
    end

    def request_schedule(**params)
      params = {sportId: SPORT_ID}.merge(params)
      uri = URI("#{BASE_URL}/schedule")
      uri.query = URI.encode_www_form(params)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "application/json"
      response = @http.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
      raise FetchFailed, "schedule returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise FetchFailed, "invalid JSON from schedule: #{e.message}"
    end

    def parse_payload(payload)
      Array(payload["dates"]).flat_map do |day|
        Array(day["games"]).filter_map { |g| parse_game(g) }
      end
    end

    def parse_game(game)
      round = GAME_TYPE_TO_ROUND[game["gameType"]]
      return nil unless round

      ParsedGame.new(
        external_id: game["gamePk"].to_s,
        home_team_external_id: game.dig("teams", "home", "team", "id").to_s,
        away_team_external_id: game.dig("teams", "away", "team", "id").to_s,
        home_score: game.dig("teams", "home", "score"),
        away_score: game.dig("teams", "away", "score"),
        kickoff_at: parse_kickoff(game["gameDate"]),
        round: round,
        week: nil,
        status: status_for(game)
      )
    end

    # Postponed and cancelled games come back with abstractGameState="Final"
    # (codedGameState "C", "D", "P", …) but no scores, which then fails the
    # Game model's "scores required for final" validation. Require scores
    # to be present before calling a game final; everything else is
    # treated as scheduled so the row still upserts cleanly.
    def status_for(game)
      state = game.dig("status", "abstractGameState")
      coded = game.dig("status", "codedGameState")
      home = game.dig("teams", "home", "score")
      away = game.dig("teams", "away", "score")
      return "final" if (state == "Final" || coded == "F") && !home.nil? && !away.nil?
      "scheduled"
    end

    def parse_kickoff(value)
      return nil if value.blank?
      Time.iso8601(value)
    rescue ArgumentError
      nil
    end
  end
end
