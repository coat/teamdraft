# frozen_string_literal: true

# Static fixture for the 30 NBA teams. Used by Sports::Installer.
#
# external_id values are NBA.com team ids (the franchise ids used by
# cdn.nba.com/static/json/staticData/scheduleLeagueV2.json), verified
# 2026-06-06 by extracting homeTeam.teamId/teamTricode pairs from the
# live 2025-26 schedule payload. default_pick_rank: 1 = first AI
# auto-pick, 30 = last resort. Loose ranking by recent-seasons contention;
# editable by admins after seeding.

module Seeds
  module NbaTeams
    EAST = "Eastern"
    WEST = "Western"

    DATA = [
      # Atlantic (East)
      {abbreviation: "BOS", name: "Boston Celtics", slug: "celtics", conference: EAST, division: "Atlantic", primary_color: "#007A33", default_pick_rank: 1, external_id: "1610612738"},
      {abbreviation: "BKN", name: "Brooklyn Nets", slug: "nets", conference: EAST, division: "Atlantic", primary_color: "#000000", default_pick_rank: 24, external_id: "1610612751"},
      {abbreviation: "NYK", name: "New York Knicks", slug: "knicks", conference: EAST, division: "Atlantic", primary_color: "#006BB6", default_pick_rank: 6, external_id: "1610612752"},
      {abbreviation: "PHI", name: "Philadelphia 76ers", slug: "76ers", conference: EAST, division: "Atlantic", primary_color: "#006BB6", default_pick_rank: 11, external_id: "1610612755"},
      {abbreviation: "TOR", name: "Toronto Raptors", slug: "raptors", conference: EAST, division: "Atlantic", primary_color: "#CE1141", default_pick_rank: 22, external_id: "1610612761"},
      # Pacific (West)
      {abbreviation: "GSW", name: "Golden State Warriors", slug: "warriors", conference: WEST, division: "Pacific", primary_color: "#1D428A", default_pick_rank: 12, external_id: "1610612744"},
      {abbreviation: "LAC", name: "Los Angeles Clippers", slug: "clippers", conference: WEST, division: "Pacific", primary_color: "#C8102E", default_pick_rank: 16, external_id: "1610612746"},
      {abbreviation: "LAL", name: "Los Angeles Lakers", slug: "lakers", conference: WEST, division: "Pacific", primary_color: "#552583", default_pick_rank: 14, external_id: "1610612747"},
      {abbreviation: "PHX", name: "Phoenix Suns", slug: "suns", conference: WEST, division: "Pacific", primary_color: "#1D1160", default_pick_rank: 19, external_id: "1610612756"},
      {abbreviation: "SAC", name: "Sacramento Kings", slug: "kings", conference: WEST, division: "Pacific", primary_color: "#5A2D81", default_pick_rank: 20, external_id: "1610612758"},
      # Central (East)
      {abbreviation: "CHI", name: "Chicago Bulls", slug: "bulls", conference: EAST, division: "Central", primary_color: "#CE1141", default_pick_rank: 23, external_id: "1610612741"},
      {abbreviation: "CLE", name: "Cleveland Cavaliers", slug: "cavaliers", conference: EAST, division: "Central", primary_color: "#860038", default_pick_rank: 4, external_id: "1610612739"},
      {abbreviation: "DET", name: "Detroit Pistons", slug: "pistons", conference: EAST, division: "Central", primary_color: "#C8102E", default_pick_rank: 17, external_id: "1610612765"},
      {abbreviation: "IND", name: "Indiana Pacers", slug: "pacers", conference: EAST, division: "Central", primary_color: "#002D62", default_pick_rank: 9, external_id: "1610612754"},
      {abbreviation: "MIL", name: "Milwaukee Bucks", slug: "bucks", conference: EAST, division: "Central", primary_color: "#00471B", default_pick_rank: 10, external_id: "1610612749"},
      # Southwest (West)
      {abbreviation: "DAL", name: "Dallas Mavericks", slug: "mavericks", conference: WEST, division: "Southwest", primary_color: "#00538C", default_pick_rank: 8, external_id: "1610612742"},
      {abbreviation: "HOU", name: "Houston Rockets", slug: "rockets", conference: WEST, division: "Southwest", primary_color: "#CE1141", default_pick_rank: 3, external_id: "1610612745"},
      {abbreviation: "MEM", name: "Memphis Grizzlies", slug: "grizzlies", conference: WEST, division: "Southwest", primary_color: "#5D76A9", default_pick_rank: 21, external_id: "1610612763"},
      {abbreviation: "NOP", name: "New Orleans Pelicans", slug: "pelicans", conference: WEST, division: "Southwest", primary_color: "#0C2340", default_pick_rank: 27, external_id: "1610612740"},
      {abbreviation: "SAS", name: "San Antonio Spurs", slug: "spurs", conference: WEST, division: "Southwest", primary_color: "#C4CED4", default_pick_rank: 30, external_id: "1610612759"},
      # Southeast (East)
      {abbreviation: "ATL", name: "Atlanta Hawks", slug: "hawks", conference: EAST, division: "Southeast", primary_color: "#E03A3E", default_pick_rank: 18, external_id: "1610612737"},
      {abbreviation: "CHA", name: "Charlotte Hornets", slug: "hornets", conference: EAST, division: "Southeast", primary_color: "#1D1160", default_pick_rank: 28, external_id: "1610612766"},
      {abbreviation: "MIA", name: "Miami Heat", slug: "heat", conference: EAST, division: "Southeast", primary_color: "#98002E", default_pick_rank: 13, external_id: "1610612748"},
      {abbreviation: "ORL", name: "Orlando Magic", slug: "magic", conference: EAST, division: "Southeast", primary_color: "#0077C0", default_pick_rank: 15, external_id: "1610612753"},
      {abbreviation: "WAS", name: "Washington Wizards", slug: "wizards", conference: EAST, division: "Southeast", primary_color: "#002B5C", default_pick_rank: 29, external_id: "1610612764"},
      # Northwest (West)
      {abbreviation: "DEN", name: "Denver Nuggets", slug: "nuggets", conference: WEST, division: "Northwest", primary_color: "#0E2240", default_pick_rank: 5, external_id: "1610612743"},
      {abbreviation: "MIN", name: "Minnesota Timberwolves", slug: "timberwolves", conference: WEST, division: "Northwest", primary_color: "#0C2340", default_pick_rank: 7, external_id: "1610612750"},
      {abbreviation: "OKC", name: "Oklahoma City Thunder", slug: "thunder", conference: WEST, division: "Northwest", primary_color: "#007AC1", default_pick_rank: 2, external_id: "1610612760"},
      {abbreviation: "POR", name: "Portland Trail Blazers", slug: "trail-blazers", conference: WEST, division: "Northwest", primary_color: "#E03A3E", default_pick_rank: 26, external_id: "1610612757"},
      {abbreviation: "UTA", name: "Utah Jazz", slug: "jazz", conference: WEST, division: "Northwest", primary_color: "#002B5C", default_pick_rank: 25, external_id: "1610612762"}
    ].freeze
  end
end
