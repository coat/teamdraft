# frozen_string_literal: true

module SportsData
  # MoneylineApp REST API (docs: https://www.moneylineapp.com/docs, API host
  # is mlapi.bet). Auth: x-api-key header; free tier: 1,000 requests/month,
  # 10 req/min.
  # Events endpoint: GET /v1/events?league=mlb&from=YYYY-MM-DD&to=YYYY-MM-DD&limit=100&page=N
  # The `to` date is an exclusive boundary (to include June 27, send
  # to=2026-06-28). Responses are enveloped: events under "data", pagination
  # under "meta" ("page"/"pages"/"total"). Future games appear as
  # "isStub": true events (odds-feed placeholders, eventId "mlb-odds-…") that
  # are later replaced by real events with different eventIds ("mlb-ev-…");
  # Sync::ApplyGames absorbs the ID change via matchup fallback matching.
  #
  # Team matching: events expose team names only (no IDs). TEAM_NAMES maps
  # MoneylineApp team names to the MLB Stats API integer IDs already stored as
  # team external_ids in the DB, so no team record migration is needed.
  #
  # Round detection: MoneylineApp events carry no gameType/round field, so all
  # fetched games are tagged "regular_season". Postseason round detection must
  # be added before the 2026 MLB playoffs begin in October.
  class MoneylineProvider < Provider
    BASE_URL = "https://mlapi.bet/v1"

    ROUND_KEY = "regular_season"

    ROUND_LABELS = {
      "regular_season" => "Regular Season"
    }.freeze

    # MoneylineApp team name → MLB Stats API team ID (stable DB external_id).
    # If a name doesn't match, the event is silently skipped (same "unmapped
    # team(s)" log path used by ApplyGames). All 30 names verified against a
    # live response on 2026-07-02 (the A's are exactly "Athletics").
    TEAM_NAMES = {
      "Arizona Diamondbacks" => "109",
      "Atlanta Braves" => "144",
      "Baltimore Orioles" => "110",
      "Boston Red Sox" => "111",
      "Chicago Cubs" => "112",
      "Chicago White Sox" => "145",
      "Cincinnati Reds" => "113",
      "Cleveland Guardians" => "114",
      "Colorado Rockies" => "115",
      "Detroit Tigers" => "116",
      "Houston Astros" => "117",
      "Kansas City Royals" => "118",
      "Los Angeles Angels" => "108",
      "Los Angeles Dodgers" => "119",
      "Miami Marlins" => "146",
      "Milwaukee Brewers" => "158",
      "Minnesota Twins" => "142",
      "New York Mets" => "121",
      "New York Yankees" => "147",
      "Athletics" => "133",
      "Philadelphia Phillies" => "143",
      "Pittsburgh Pirates" => "134",
      "San Diego Padres" => "135",
      "San Francisco Giants" => "137",
      "Seattle Mariners" => "136",
      "St. Louis Cardinals" => "138",
      "Tampa Bay Rays" => "139",
      "Texas Rangers" => "140",
      "Toronto Blue Jays" => "141",
      "Washington Nationals" => "120"
    }.freeze

    def initialize(season:)
      super
    end

    def fetch_games(rounds: nil, dates: nil)
      from, to = date_range(dates)
      events = fetch_all_events(from:, to:)
      games = events.filter_map { |e| parse_event(e) }
      games = filter_by_dates(games, dates) if dates
      games = games.select { |g| Array(rounds).map(&:to_s).include?(g.round) } if rounds
      games
    end

    def round_numbers
      [ROUND_KEY]
    end

    def round_labels
      ROUND_LABELS.dup
    end

    private

    def date_range(dates)
      if dates
        list = Array(dates).map(&:to_s).sort
        from = list.first
        to = (Date.parse(list.last) + 1).iso8601
      else
        from = @season.starts_on.iso8601
        to = (@season.ends_on + 1).iso8601
      end
      [from, to]
    end

    def fetch_all_events(from:, to:)
      page = 1
      pages = 1
      events = []
      while page <= pages
        resp = request_events(from:, to:, page:)
        events.concat(Array(resp["data"]))
        pages = resp.dig("meta", "pages").to_i
        pages = 1 if pages < 1
        page += 1
      end
      events
    end

    def request_events(from:, to:, page:)
      uri = URI("#{BASE_URL}/events")
      uri.query = URI.encode_www_form(league: "mlb", from:, to:, limit: 100, page:)
      api_key = ENV.fetch("MONEYLINE_API_KEY", nil)
      get_json(uri.to_s, headers: {"x-api-key" => api_key, "Accept" => "application/json"}, label: "events")
    end

    def parse_event(event)
      home_ext = TEAM_NAMES[event["homeTeamName"]]
      away_ext = TEAM_NAMES[event["awayTeamName"]]
      return nil unless home_ext && away_ext

      ParsedGame.new(
        external_id: event["eventId"].to_s,
        home_team_external_id: home_ext,
        away_team_external_id: away_ext,
        home_score: event.dig("scores", "home"),
        away_score: event.dig("scores", "away"),
        starts_at: parse_start(event["startTime"]),
        round: ROUND_KEY,
        week: nil,
        status: status_for(event)
      )
    end

    def status_for(event)
      home = event.dig("scores", "home")
      away = event.dig("scores", "away")
      return "final" if event["status"] == "final" && !home.nil? && !away.nil?
      "scheduled"
    end

    def filter_by_dates(games, dates)
      wanted = Array(dates).map { |d| d.is_a?(Date) ? d : Date.parse(d.to_s) }.to_set
      games.select { |g| g.starts_at && wanted.include?(g.starts_at.to_date) }
    end
  end
end
