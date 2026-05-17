# frozen_string_literal: true

require_relative "seeds/nfl_teams"
require_relative "seeds/nba_teams"

SPORTS_SEED = [
  {
    key: "nfl",
    name: "NFL",
    about_blurb: "Inspired by the Mina Kimes Show's yearly NFL team draft: take turns picking entire NFL teams, then watch points roll in as the season plays out.",
    teams: Seeds::NflTeams::DATA,
    scoring_rules: [
      {event_type: "regular_win",             kind: "regular_win",        round_key: nil,            points: 1,  label: "Regular-season win",                short_label: "Regular Season", display_order: 0},
      {event_type: "playoff_appearance",      kind: "playoff_appearance", round_key: "wildcard",     points: 5,  label: "Made the playoffs",                 short_label: "Wild Card",      display_order: 1, bye_backfill: true},
      {event_type: "divisional_appearance",   kind: "playoff_appearance", round_key: "divisional",   points: 5,  label: "Made the divisional round",         short_label: "Divisional",     display_order: 2},
      {event_type: "conference_appearance",   kind: "playoff_appearance", round_key: "conference",   points: 10, label: "Made the conference championship", short_label: "Conference",     display_order: 3},
      {event_type: "championship_appearance", kind: "playoff_appearance", round_key: "championship", points: 10, label: "Made the Super Bowl",               short_label: "Super Bowl",     display_order: 4},
      {event_type: "championship_win",        kind: "championship_win",   round_key: nil,            points: 5,  label: "Won the Super Bowl",                short_label: "Champion",       display_order: 5}
    ],
    season: ->(year) {
      {year: year, label: "#{year} NFL Season",
       starts_on: Date.new(year, 9, 1), ends_on: Date.new(year + 1, 2, 28)}
    },
    season_year: -> { (Date.current.month >= 9) ? Date.current.year : Date.current.year - 1 }
  },
  {
    key: "nba",
    name: "NBA",
    about_blurb: "Same draft, hardwood edition: take turns picking entire NBA teams and chase points through regular-season wins, the play-in tournament, and a deep playoff run.",
    teams: Seeds::NbaTeams::DATA,
    scoring_rules: [
      {event_type: "regular_win",            kind: "regular_win",        round_key: nil,           points: 1,  label: "Regular-season win",              short_label: "Regular Season", display_order: 0},
      {event_type: "play_in_appearance",     kind: "playoff_appearance", round_key: "play_in",     points: 2,  label: "Made the play-in tournament",     short_label: "Play-In",        display_order: 1},
      {event_type: "first_round_appearance", kind: "playoff_appearance", round_key: "first_round", points: 5,  label: "Made the first round",            short_label: "First Round",    display_order: 2},
      {event_type: "conf_semis_appearance",  kind: "playoff_appearance", round_key: "conf_semis",  points: 8,  label: "Made the conference semifinals", short_label: "Conf Semis",     display_order: 3},
      {event_type: "conf_finals_appearance", kind: "playoff_appearance", round_key: "conf_finals", points: 10, label: "Made the conference finals",     short_label: "Conf Finals",    display_order: 4},
      {event_type: "finals_appearance",      kind: "playoff_appearance", round_key: "finals",      points: 12, label: "Made the NBA Finals",             short_label: "Finals",         display_order: 5},
      {event_type: "championship_win",       kind: "championship_win",   round_key: nil,           points: 8,  label: "Won the NBA Finals",              short_label: "Champion",       display_order: 6}
    ],
    season: ->(year) {
      {year: year, label: "#{year}-#{year + 1} NBA Season",
       starts_on: Date.new(year, 10, 1), ends_on: Date.new(year + 1, 6, 30)}
    },
    season_year: -> { (Date.current.month >= 10) ? Date.current.year : Date.current.year - 1 }
  }
].freeze

ActiveRecord::Base.transaction do
  SPORTS_SEED.each do |cfg|
    sport = Sport.find_or_initialize_by(key: cfg[:key])
    sport.name = cfg[:name]
    sport.about_blurb = cfg[:about_blurb]
    sport.save!

    cfg[:teams].each do |attrs|
      team = Team.find_or_initialize_by(sport_id: sport.id, slug: attrs[:slug])
      team.assign_attributes(attrs)
      team.save!
    end

    cfg[:scoring_rules].each do |attrs|
      rule = ScoringRule.find_or_initialize_by(sport_id: sport.id, event_type: attrs[:event_type])
      rule.assign_attributes(attrs.except(:event_type))
      rule.save!
    end

    year = cfg[:season_year].call
    season_attrs = cfg[:season].call(year)
    season = Season.find_or_create_by!(sport_id: sport.id, year: season_attrs[:year]) do |s|
      s.label = season_attrs[:label]
      s.starts_on = season_attrs[:starts_on]
      s.ends_on = season_attrs[:ends_on]
      s.status = "active"
    end

    sport.teams.find_each do |team|
      SeasonTeam.find_or_create_by!(season_id: season.id, team_id: team.id)
    end
  end
end
