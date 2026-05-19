# frozen_string_literal: true

# Static fixture for the 30 MLB teams. Used by Sports::Installer.
#
# external_id values are TheSportsDB team ids, derived 2026-05-18 by combining
# search_all_teams.php?l=MLB (alphabetical first 10 only on the free tier) with
# eventsday.php?l=4424 / eventsround.php?id=4424 responses cached under
# tmp/thesportsdb/mlb_2025/. default_pick_rank: 1 = first AI auto-pick, 30 =
# last resort; loosely based on 2025 results and 2026 outlook.

module Seeds
  module MlbTeams
    AL = "AL"
    NL = "NL"

    DATA = [
      # AL East
      {abbreviation: "BAL", name: "Baltimore Orioles",     slug: "orioles",    conference: AL, division: "East",    primary_color: "#DF4601", default_pick_rank: 14, external_id: "135251"},
      {abbreviation: "BOS", name: "Boston Red Sox",        slug: "red-sox",    conference: AL, division: "East",    primary_color: "#BD3039", default_pick_rank: 10, external_id: "135252"},
      {abbreviation: "NYY", name: "New York Yankees",      slug: "yankees",    conference: AL, division: "East",    primary_color: "#003087", default_pick_rank: 4,  external_id: "135260"},
      {abbreviation: "TB",  name: "Tampa Bay Rays",        slug: "rays",       conference: AL, division: "East",    primary_color: "#092C5C", default_pick_rank: 19, external_id: "135263"},
      {abbreviation: "TOR", name: "Toronto Blue Jays",     slug: "blue-jays",  conference: AL, division: "East",    primary_color: "#134A8E", default_pick_rank: 2,  external_id: "135265"},
      # AL Central
      {abbreviation: "CWS", name: "Chicago White Sox",     slug: "white-sox",  conference: AL, division: "Central", primary_color: "#27251F", default_pick_rank: 30, external_id: "135253"},
      {abbreviation: "CLE", name: "Cleveland Guardians",   slug: "guardians",  conference: AL, division: "Central", primary_color: "#00385D", default_pick_rank: 13, external_id: "135254"},
      {abbreviation: "DET", name: "Detroit Tigers",        slug: "tigers",     conference: AL, division: "Central", primary_color: "#0C2340", default_pick_rank: 9,  external_id: "135255"},
      {abbreviation: "KC",  name: "Kansas City Royals",    slug: "royals",     conference: AL, division: "Central", primary_color: "#004687", default_pick_rank: 17, external_id: "135257"},
      {abbreviation: "MIN", name: "Minnesota Twins",       slug: "twins",      conference: AL, division: "Central", primary_color: "#002B5C", default_pick_rank: 22, external_id: "135259"},
      # AL West
      {abbreviation: "HOU", name: "Houston Astros",        slug: "astros",     conference: AL, division: "West",    primary_color: "#002D62", default_pick_rank: 8,  external_id: "135256"},
      {abbreviation: "LAA", name: "Los Angeles Angels",    slug: "angels",     conference: AL, division: "West",    primary_color: "#BA0021", default_pick_rank: 27, external_id: "135258"},
      {abbreviation: "ATH", name: "Athletics",             slug: "athletics",  conference: AL, division: "West",    primary_color: "#003831", default_pick_rank: 29, external_id: "135261"},
      {abbreviation: "SEA", name: "Seattle Mariners",      slug: "mariners",   conference: AL, division: "West",    primary_color: "#0C2C56", default_pick_rank: 6,  external_id: "135262"},
      {abbreviation: "TEX", name: "Texas Rangers",         slug: "rangers",    conference: AL, division: "West",    primary_color: "#003278", default_pick_rank: 21, external_id: "135264"},
      # NL East
      {abbreviation: "ATL", name: "Atlanta Braves",        slug: "braves",     conference: NL, division: "East",    primary_color: "#CE1141", default_pick_rank: 11, external_id: "135268"},
      {abbreviation: "MIA", name: "Miami Marlins",         slug: "marlins",    conference: NL, division: "East",    primary_color: "#00A3E0", default_pick_rank: 25, external_id: "135273"},
      {abbreviation: "NYM", name: "New York Mets",         slug: "mets",       conference: NL, division: "East",    primary_color: "#002D72", default_pick_rank: 5,  external_id: "135275"},
      {abbreviation: "PHI", name: "Philadelphia Phillies", slug: "phillies",   conference: NL, division: "East",    primary_color: "#E81828", default_pick_rank: 3,  external_id: "135276"},
      {abbreviation: "WSH", name: "Washington Nationals",  slug: "nationals",  conference: NL, division: "East",    primary_color: "#AB0003", default_pick_rank: 26, external_id: "135281"},
      # NL Central
      {abbreviation: "CHC", name: "Chicago Cubs",          slug: "cubs",       conference: NL, division: "Central", primary_color: "#0E3386", default_pick_rank: 7,  external_id: "135269"},
      {abbreviation: "CIN", name: "Cincinnati Reds",       slug: "reds",       conference: NL, division: "Central", primary_color: "#C6011F", default_pick_rank: 18, external_id: "135270"},
      {abbreviation: "MIL", name: "Milwaukee Brewers",     slug: "brewers",    conference: NL, division: "Central", primary_color: "#12284B", default_pick_rank: 12, external_id: "135274"},
      {abbreviation: "PIT", name: "Pittsburgh Pirates",    slug: "pirates",    conference: NL, division: "Central", primary_color: "#FDB827", default_pick_rank: 24, external_id: "135277"},
      {abbreviation: "STL", name: "St. Louis Cardinals",   slug: "cardinals",  conference: NL, division: "Central", primary_color: "#C41E3A", default_pick_rank: 20, external_id: "135280"},
      # NL West
      {abbreviation: "ARI", name: "Arizona Diamondbacks",  slug: "diamondbacks", conference: NL, division: "West",  primary_color: "#A71930", default_pick_rank: 16, external_id: "135267"},
      {abbreviation: "COL", name: "Colorado Rockies",      slug: "rockies",    conference: NL, division: "West",    primary_color: "#33006F", default_pick_rank: 28, external_id: "135271"},
      {abbreviation: "LAD", name: "Los Angeles Dodgers",   slug: "dodgers",    conference: NL, division: "West",    primary_color: "#005A9C", default_pick_rank: 1,  external_id: "135272"},
      {abbreviation: "SD",  name: "San Diego Padres",      slug: "padres",     conference: NL, division: "West",    primary_color: "#2F241D", default_pick_rank: 15, external_id: "135278"},
      {abbreviation: "SF",  name: "San Francisco Giants",  slug: "giants",     conference: NL, division: "West",    primary_color: "#FD5A1E", default_pick_rank: 23, external_id: "135279"}
    ].freeze
  end
end
