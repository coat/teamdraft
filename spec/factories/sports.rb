FactoryBot.define do
  factory :sport do
    sequence(:key) { |n| "sport-#{n}" }
    name { "Sport" }
    active { true }

    # Default sport ships with the 6-event NFL-shaped scoring rules so specs
    # that don't care about per-sport differences get sane defaults.
    transient do
      with_scoring_rules { true }
    end

    after(:create) do |sport, evaluator|
      next unless evaluator.with_scoring_rules
      next if sport.scoring_rules.any?
      [
        {event_type: "regular_win",             kind: "regular_win",        round_key: nil,            points: 1,  label: "Regular-season win",                short_label: "Regular Season", display_order: 0},
        {event_type: "playoff_appearance",      kind: "playoff_appearance", round_key: "wildcard",     points: 5,  label: "Made the playoffs",                 short_label: "Wild Card",      display_order: 1, bye_backfill: true},
        {event_type: "divisional_appearance",   kind: "playoff_appearance", round_key: "divisional",   points: 5,  label: "Made the divisional round",         short_label: "Divisional",     display_order: 2},
        {event_type: "conference_appearance",   kind: "playoff_appearance", round_key: "conference",   points: 10, label: "Made the conference championship", short_label: "Conference",     display_order: 3},
        {event_type: "championship_appearance", kind: "playoff_appearance", round_key: "championship", points: 10, label: "Made the Super Bowl",              short_label: "Super Bowl",     display_order: 4},
        {event_type: "championship_win",        kind: "championship_win",   round_key: nil,            points: 5,  label: "Won the Super Bowl",                short_label: "Champion",       display_order: 5}
      ].each { |attrs| sport.scoring_rules.create!(attrs) }
    end

    trait :nfl do
      key { "nfl" }
      name { "NFL" }
    end

    trait :nba do
      key { "nba" }
      name { "NBA" }
      with_scoring_rules { false }
      after(:create) do |sport, _|
        [
          {event_type: "regular_win",            kind: "regular_win",        round_key: nil,           points: 1,  label: "Regular-season win",              short_label: "Regular Season", display_order: 0},
          {event_type: "play_in_appearance",     kind: "playoff_appearance", round_key: "play_in",     points: 2,  label: "Made the play-in tournament",     short_label: "Play-In",        display_order: 1},
          {event_type: "first_round_appearance", kind: "playoff_appearance", round_key: "first_round", points: 5,  label: "Made the first round",            short_label: "First Round",    display_order: 2},
          {event_type: "conf_semis_appearance",  kind: "playoff_appearance", round_key: "conf_semis",  points: 8,  label: "Made the conference semifinals", short_label: "Conf Semis",     display_order: 3},
          {event_type: "conf_finals_appearance", kind: "playoff_appearance", round_key: "conf_finals", points: 10, label: "Made the conference finals",     short_label: "Conf Finals",    display_order: 4},
          {event_type: "finals_appearance",      kind: "playoff_appearance", round_key: "finals",      points: 12, label: "Made the NBA Finals",             short_label: "Finals",         display_order: 5},
          {event_type: "championship_win",       kind: "championship_win",   round_key: nil,           points: 8,  label: "Won the NBA Finals",              short_label: "Champion",       display_order: 6}
        ].each { |attrs| sport.scoring_rules.create!(attrs) }
      end
    end

    trait :mlb do
      key { "mlb" }
      name { "MLB" }
      with_scoring_rules { false }
      after(:create) do |sport, _|
        [
          {event_type: "regular_win",                kind: "regular_win",        round_key: nil,               points: 1,  label: "Regular-season win",        short_label: "Regular Season",  display_order: 0},
          {event_type: "wildcard_appearance",        kind: "playoff_appearance", round_key: "wildcard",        points: 3,  label: "Made the Wild Card Series", short_label: "Wild Card",       display_order: 1},
          {event_type: "division_series_appearance", kind: "playoff_appearance", round_key: "division_series", points: 5,  label: "Made the Division Series",  short_label: "Division Series", display_order: 2},
          {event_type: "lcs_appearance",             kind: "playoff_appearance", round_key: "lcs",             points: 8,  label: "Made the LCS",              short_label: "LCS",             display_order: 3},
          {event_type: "world_series_appearance",    kind: "playoff_appearance", round_key: "world_series",    points: 12, label: "Made the World Series",     short_label: "World Series",    display_order: 4},
          {event_type: "championship_win",           kind: "championship_win",   round_key: nil,               points: 8,  label: "Won the World Series",      short_label: "Champion",        display_order: 5}
        ].each { |attrs| sport.scoring_rules.create!(attrs) }
      end
    end
  end

  factory :scoring_rule do
    sport
    sequence(:event_type) { |n| "event_#{n}" }
    kind { "regular_win" }
    round_key { nil }
    points { 1 }
    label { "Some event" }
    short_label { "Event" }
    sequence(:display_order)
  end
end
