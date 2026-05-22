# frozen_string_literal: true

require Rails.root.join("db/seeds/nba_teams")

module Sports
  module Configs
    module Nba
      def self.build
        Sports::Config.new(
          key: "nba",
          name: "NBA",
          display_order: 3,
          about_blurb: "Same draft, hardwood edition: take turns picking entire NBA teams and chase points through regular-season wins, the play-in tournament, and a deep playoff run.",
          teams: Seeds::NbaTeams::DATA,
          scoring_rules: [
            {event_type: "regular_win", kind: "regular_win", round_key: nil, points: 1, label: "Regular-season win", short_label: "Regular Season", display_order: 0},
            {event_type: "play_in_appearance", kind: "playoff_appearance", round_key: "play_in", points: 2, label: "Made the play-in tournament", short_label: "Play-In", display_order: 1},
            {event_type: "first_round_appearance", kind: "playoff_appearance", round_key: "first_round", points: 5, label: "Made the first round", short_label: "First Round", display_order: 2},
            {event_type: "conf_semis_appearance", kind: "playoff_appearance", round_key: "conf_semis", points: 8, label: "Made the conference semifinals", short_label: "Conf Semis", display_order: 3},
            {event_type: "conf_finals_appearance", kind: "playoff_appearance", round_key: "conf_finals", points: 10, label: "Made the conference finals", short_label: "Conf Finals", display_order: 4},
            {event_type: "finals_appearance", kind: "playoff_appearance", round_key: "finals", points: 12, label: "Made the NBA Finals", short_label: "Finals", display_order: 5},
            {event_type: "championship_win", kind: "championship_win", round_key: nil, points: 8, label: "Won the NBA Finals", short_label: "Champion", display_order: 6}
          ],
          current_season: ->(today) {
            year = (today.month >= 10) ? today.year : today.year - 1
            {year: year, label: "#{year}-#{year + 1} NBA Season",
             starts_on: Date.new(year, 10, 1), ends_on: Date.new(year + 1, 6, 30)}
          }
        )
      end
    end
  end
end
