# frozen_string_literal: true

require "net/http"
require "json"

module SportsData
  # TheSportsDB v1 JSON API. Free tier uses API key "123" (rate-limited).
  # https://www.thesportsdb.com/free_api.php
  #
  # Notes:
  # - NFL idLeague is 4391; future sports will need their own mapping.
  # - Their `strSeason` for NFL is "2025-2026" style (across calendar years).
  # - Round numbering: 1..18 = regular season weeks; 125 = Wild Card,
  #   150 = Divisional, 160 = Conference, 200 = Super Bowl. (Other ints
  #   show up for preseason / pro bowl etc and are filtered out.)
  class TheSportsDbProvider < Provider
    BASE_URL = "https://www.thesportsdb.com/api/v1/json"
    DEFAULT_KEY = "123"

    SPORT_LEAGUE_ID = {
      "nfl" => "4391"
    }.freeze

    PLAYOFF_ROUNDS = {
      "125" => "wildcard",
      "150" => "divisional",
      "160" => "conference",
      "200" => "championship"
    }.freeze

    def initialize(season:, api_key: ENV.fetch("THESPORTSDB_API_KEY", DEFAULT_KEY), http: Net::HTTP)
      super(season:)
      @api_key = api_key
      @http = http
    end

    def fetch_games(since: nil)
      payload = request("eventsseason.php", id: league_id, s: season_string)
      events = Array(payload["events"])
      events.filter_map { |e| parse_event(e) }
    end

    private

    def league_id
      SPORT_LEAGUE_ID.fetch(@season.sport.key) {
        raise FetchFailed, "no TheSportsDB league id mapped for sport #{@season.sport.key.inspect}"
      }
    end

    # NFL season "2025-2026"; format may differ for other sports later.
    def season_string
      "#{@season.year}-#{@season.year + 1}"
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
      return PLAYOFF_ROUNDS[str] if PLAYOFF_ROUNDS.key?(str)
      n = Integer(str, exception: false)
      return "regular_season" if n && (1..22).cover?(n) && PLAYOFF_ROUNDS.exclude?(str) && n <= 18
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
