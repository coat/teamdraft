# frozen_string_literal: true

require "net/http"
require "json"

module SportsData
  # NBA.com's static schedule CDN
  # (https://cdn.nba.com/static/json/staticData/scheduleLeagueV2.json).
  # No API key, no auth, no rate-limit cap — one CDN-served blob for the
  # whole current season (~8 MB), regular season + Play-In + every playoff
  # round. Verified live on 2026-06-06. The CDN rejects requests without
  # a Referer header (403), so we always send one.
  #
  # This provider only handles the *current* NBA season — the endpoint
  # only serves whatever season is in progress. Past NBA seasons should
  # stay on whatever provider stored them (typically TheSportsDB).
  #
  # round_key strings exposed on ParsedGame (regular_season, play_in,
  # first_round, conf_semis, conf_finals, finals) match the NBA scoring
  # rules in lib/sports/configs/nba.rb.
  class NbaStatsApiProvider < Provider
    BASE_URL = "https://cdn.nba.com/static/json/staticData"
    USER_AGENT = "Mozilla/5.0 (compatible; teamdraft/1.0)"
    REFERER = "https://www.nba.com/"

    REGULAR_SEASON = "regular_season"

    # Exact-match labels from gameLabel that map to a postseason round_key.
    # Both conference halves of a round share one round_key.
    PLAYOFF_LABEL_TO_ROUND = {
      "SoFi Play-In Tournament" => "play_in",
      "East First Round" => "first_round",
      "West First Round" => "first_round",
      "East Conf. Semifinals" => "conf_semis",
      "West Conf. Semifinals" => "conf_semis",
      "East Conf. Finals" => "conf_finals",
      "West Conf. Finals" => "conf_finals",
      "NBA Finals" => "finals"
    }.freeze

    # Labels we explicitly drop — exhibition and non-counting events.
    SKIP_LABEL_PREFIXES = ["Preseason", "All-Star", "Rising Stars"].freeze

    ROUND_KEYS = ([REGULAR_SEASON] + PLAYOFF_LABEL_TO_ROUND.values.uniq).freeze

    ROUND_LABELS = {
      "regular_season" => "Regular Season",
      "play_in" => "Play-In",
      "first_round" => "First Round",
      "conf_semis" => "Conf. Semifinals",
      "conf_finals" => "Conf. Finals",
      "finals" => "NBA Finals"
    }.freeze

    def initialize(season:, http: Net::HTTP)
      super(season:)
      @http = http
    end

    def fetch_games(rounds: nil, dates: nil)
      validate_rounds!(rounds)
      payload = request_schedule
      games = parse_payload(payload)
      games = filter_by_dates(games, dates) if dates
      games = games.select { |g| Array(rounds).map(&:to_s).include?(g.round) } if rounds
      games
    end

    def round_numbers
      ROUND_KEYS.dup
    end

    def round_labels
      ROUND_LABELS.dup
    end

    private

    def validate_rounds!(rounds)
      return if rounds.nil?
      requested = Array(rounds).map(&:to_s)
      unknown = requested - ROUND_KEYS
      raise FetchFailed, "unknown round(s): #{unknown.inspect}" if unknown.any?
    end

    def filter_by_dates(games, dates)
      wanted = Array(dates).map { |d| d.is_a?(Date) ? d : Date.parse(d.to_s) }.to_set
      games.select { |g| g.starts_at && wanted.include?(g.starts_at.to_date) }
    end

    def request_schedule
      uri = URI("#{BASE_URL}/scheduleLeagueV2.json")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT
      request["Accept"] = "application/json"
      request["Referer"] = REFERER
      response = @http.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
      raise FetchFailed, "schedule returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise FetchFailed, "invalid JSON from schedule: #{e.message}"
    end

    def parse_payload(payload)
      schedule = payload["leagueSchedule"] || {}
      verify_season!(schedule["seasonYear"])
      Array(schedule["gameDates"]).flat_map do |day|
        Array(day["games"]).filter_map { |g| parse_game(g) }
      end
    end

    # scheduleLeagueV2 always serves the current season. If the season we
    # were given isn't the one the CDN is serving, fail loudly rather than
    # silently sync the wrong year.
    def verify_season!(season_year)
      expected = expected_season_year
      return if season_year.to_s == expected
      raise FetchFailed, "schedule seasonYear #{season_year.inspect} does not match expected #{expected.inspect}"
    end

    def expected_season_year
      start_year = @season.year.to_i
      "#{start_year}-#{(start_year + 1).to_s[-2..]}"
    end

    def parse_game(game)
      label = game["gameLabel"].to_s
      return nil if SKIP_LABEL_PREFIXES.any? { |p| label.start_with?(p) }
      round = round_for(label)
      return nil unless round

      ParsedGame.new(
        external_id: game["gameId"].to_s,
        home_team_external_id: game.dig("homeTeam", "teamId").to_s,
        away_team_external_id: game.dig("awayTeam", "teamId").to_s,
        home_score: parse_score(game.dig("homeTeam", "score")),
        away_score: parse_score(game.dig("awayTeam", "score")),
        starts_at: parse_start(game["gameDateTimeUTC"]),
        round: round,
        week: parsed_week_for(round, game["weekNumber"]),
        status: status_for(game)
      )
    end

    def round_for(label)
      return PLAYOFF_LABEL_TO_ROUND[label] if PLAYOFF_LABEL_TO_ROUND.key?(label)
      REGULAR_SEASON
    end

    # NBA Cup, Global Games and the like still carry a real weekNumber and
    # count toward standings, so we keep the week. Playoff rounds don't
    # carry a meaningful week number.
    def parsed_week_for(round, week_number)
      return nil unless round == REGULAR_SEASON
      week = week_number.to_i
      (week > 0) ? week : nil
    end

    # gameStatus: 1 = scheduled, 2 = in progress, 3 = final. Mirror the
    # MLB provider's rule: only call a game final when both scores are
    # present, so postponed/cancelled rows that come back with status=3
    # but blank scores don't trip Game's "scores required for final"
    # validation.
    def status_for(game)
      home = parse_score(game.dig("homeTeam", "score"))
      away = parse_score(game.dig("awayTeam", "score"))
      return "final" if game["gameStatus"].to_i == 3 && !home.nil? && !away.nil?
      "scheduled"
    end

    # Pre-game rows return score = 0 (not null). We can't distinguish "0
    # pre-game" from "0 final" from the score alone, so we lean on
    # gameStatus in status_for and just forward whatever number we see.
    def parse_score(value)
      return nil if value.nil?
      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_start(value)
      return nil if value.blank?
      Time.iso8601(value)
    rescue ArgumentError
      nil
    end
  end
end
