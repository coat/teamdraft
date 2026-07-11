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
  # Stubs shadowed by a real event in the same response are dropped here so
  # ApplyGames' matchup fallback can adopt the stub's existing row; stub->real
  # transitions across separate syncs are absorbed by the same fallback.
  #
  # Team matching: events expose team names only (no IDs). TEAM_NAMES maps
  # MoneylineApp team names to the MLB Stats API integer IDs already stored as
  # team external_ids in the DB, so no team record migration is needed.
  #
  # Round detection: events carry no gameType/round field, so playoff rounds
  # come from the season's admin-configured round_windows (Eastern-date lookup
  # via Season#round_for); anything outside a window is regular_season.
  class MoneylineProvider < Provider
    BASE_URL = "https://mlapi.bet/v1"

    TIME_ZONE = "America/New_York"

    ROUND_KEY = "regular_season"

    # MoneylineApp team name -> MLB Stats API team ID (stable DB external_id).
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
      events = drop_shadowed_stubs(fetch_all_events(from:, to:))
      games = events.filter_map { |e| parse_event(e) }
      # Spring training games are indistinguishable in the payload (no
      # gameType/round field), so use the season boundary: anything dated
      # before starts_on is exhibition, even if the sync range reaches back
      # further.
      games = games.reject { |g| g.starts_at && local_date(g.starts_at) < @season.starts_on }
      games = filter_by_dates(games, dates) if dates
      games = games.select { |g| Array(rounds).map(&:to_s).include?(g.round) } if rounds
      games
    end

    def round_numbers
      [ROUND_KEY] + ordered_windows.map(&:first)
    end

    def round_labels
      labels = {ROUND_KEY => "Regular Season"}
      ordered_windows.each { |key, short_label| labels[key] = short_label || key.titleize }
      labels
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

      starts_at = parse_start(event["startTime"])

      ParsedGame.new(
        external_id: event["eventId"].to_s,
        home_team_external_id: home_ext,
        away_team_external_id: away_ext,
        home_score: event.dig("scores", "home"),
        away_score: event.dig("scores", "away"),
        starts_at: starts_at,
        round: round_key_for(starts_at),
        week: nil,
        status: status_for(event)
      )
    end

    # The API documents exactly three statuses: scheduled, in_progress,
    # final (postponed games get no status of their own - they linger as
    # scheduled 0-0 events under the original start time). in_progress
    # passes through so Season#score_sync_reason's :live gate keeps polling
    # games that run past the post-start sync window. Gating final on both
    # scores keeps a scoreless "final" from tripping Game's
    # final-games-have-scores validation.
    def status_for(event)
      home = event.dig("scores", "home")
      away = event.dig("scores", "away")
      return "final" if event["status"] == "final" && !home.nil? && !away.nil?
      return "in_progress" if event["status"] == "in_progress"
      "scheduled"
    end

    def filter_by_dates(games, dates)
      wanted = Array(dates).map { |d| d.is_a?(Date) ? d : Date.parse(d.to_s) }.to_set
      games.select { |g| g.starts_at && wanted.include?(local_date(g.starts_at)) }
    end

    # MLB schedules by Eastern-time date (a 10pm ET start is still "today's
    # game") and mlapi.bet's from/to params match that, so date comparisons
    # must not use the UTC date: it rolls over at 8pm ET and every night game
    # on a sync range's last day would be fetched but then dropped here.
    def local_date(time)
      time.in_time_zone(TIME_ZONE).to_date
    end

    def round_key_for(starts_at)
      return ROUND_KEY if starts_at.nil?
      @season.round_for(local_date(starts_at)) || ROUND_KEY
    end

    # Window keys in the sport's scoring-rule display order - jsonb does not
    # preserve insertion order, so the admin dropdown would otherwise list
    # rounds by key length.
    def ordered_windows
      configured = @season.round_windows.keys
      rules = @season.sport.scoring_rules.ordered
        .where(kind: "playoff_appearance").pluck(:round_key, :short_label).to_h
      ordered = rules.keys.select { |k| configured.include?(k) } + (configured - rules.keys)
      ordered.map { |k| [k, rules[k]] }
    end

    # Moneyline can return a stub ("isStub" odds placeholder) AND its real
    # event in one response. If the stub survives into the batch it
    # exact-matches its own existing row and claims it, forcing the real
    # event to insert a duplicate; with the stub gone, ApplyGames' matchup
    # fallback adopts the stub's row instead. Stubs with no real
    # counterpart are legitimate future-game placeholders and are kept.
    # A doubleheader stub dropped against game 1's real event costs at most a row-identity swap that converges once game 2's real event syncs.
    def drop_shadowed_stubs(events)
      real_keys = events.reject { |e| stub?(e) }.map { |e| matchup_key(e) }.to_set
      events.reject { |e| stub?(e) && real_keys.include?(matchup_key(e)) }
    end

    def stub?(event)
      return event["isStub"] unless event["isStub"].nil?
      event["eventId"].to_s.start_with?("mlb-odds-")
    end

    def matchup_key(event)
      starts = parse_start(event["startTime"])
      [event["homeTeamName"], event["awayTeamName"], starts && local_date(starts)]
    end
  end
end
