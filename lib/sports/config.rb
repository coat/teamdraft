# frozen_string_literal: true

# Plain value object describing everything Sports::Installer needs to
# materialize a new sport: display name, about-page copy, teams, scoring
# rules, and (optionally) a generator that decides what the "current
# season" is on a given date.
#
# Each supported sport lives in lib/sports/configs/<key>.rb and returns
# one of these from `.build`.

module Sports
  Config = Struct.new(:key, :name, :display_order, :about_blurb, :teams, :scoring_rules, :current_season, keyword_init: true)
end
