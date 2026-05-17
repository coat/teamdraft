# frozen_string_literal: true

require Rails.root.join("db/seeds/nfl_teams")

module Sports
  module Configs
    module Nfl
      def self.build
        Sports::Config.new(
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
          current_season: ->(today) {
            year = (today.month >= 9) ? today.year : today.year - 1
            {year: year, label: "#{year} NFL Season",
             starts_on: Date.new(year, 9, 1), ends_on: Date.new(year + 1, 2, 28)}
          }
        )
      end
    end
  end
end
