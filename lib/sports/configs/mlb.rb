# frozen_string_literal: true

require Rails.root.join("db/seeds/mlb_teams")

module Sports
  module Configs
    module Mlb
      def self.build
        Sports::Config.new(
          key: "mlb",
          name: "MLB",
          about_blurb: "Same draft, baseball edition: take turns picking entire MLB teams and chase points through 162 games and a five-round postseason.",
          teams: Seeds::MlbTeams::DATA,
          scoring_rules: [
            {event_type: "regular_win",                 kind: "regular_win",        round_key: nil,               points: 1,  label: "Regular-season win",            short_label: "Regular Season", display_order: 0},
            {event_type: "wildcard_appearance",         kind: "playoff_appearance", round_key: "wildcard",        points: 3,  label: "Made the Wild Card Series",     short_label: "Wild Card",      display_order: 1},
            {event_type: "division_series_appearance",  kind: "playoff_appearance", round_key: "division_series", points: 5,  label: "Made the Division Series",      short_label: "Division Series", display_order: 2},
            {event_type: "lcs_appearance",              kind: "playoff_appearance", round_key: "lcs",             points: 8,  label: "Made the LCS",                  short_label: "LCS",            display_order: 3},
            {event_type: "world_series_appearance",     kind: "playoff_appearance", round_key: "world_series",    points: 12, label: "Made the World Series",         short_label: "World Series",   display_order: 4},
            {event_type: "championship_win",            kind: "championship_win",   round_key: nil,               points: 8,  label: "Won the World Series",          short_label: "Champion",       display_order: 5}
          ],
          current_season: ->(today) {
            year = (today.month >= 11) ? today.year + 1 : today.year
            {year: year, label: "#{year} MLB Season",
             starts_on: Date.new(year, 3, 15), ends_on: Date.new(year, 11, 5),
             external_provider: "mlb_stats_api", external_id: year.to_s}
          }
        )
      end
    end
  end
end
