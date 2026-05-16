# frozen_string_literal: true

# Static fixture for the 32 NFL teams. Used by db/seeds.rb.

module Seeds
  module NflTeams
    AFC = "AFC"
    NFC = "NFC"

    # default_pick_rank: 1 = first auto-pick when AFK, 32 = last resort.
    # Editable by admins later
    DATA = [
      # AFC East
      {abbreviation: "BUF", name: "Buffalo Bills", slug: "bills", conference: AFC, division: "East", primary_color: "#00338D", default_pick_rank: 5, external_id: "134918"},
      {abbreviation: "MIA", name: "Miami Dolphins", slug: "dolphins", conference: AFC, division: "East", primary_color: "#008E97", default_pick_rank: 22, external_id: "134919"},
      {abbreviation: "NE", name: "New England Patriots", slug: "patriots", conference: AFC, division: "East", primary_color: "#002244", default_pick_rank: 2, external_id: "134920"},
      {abbreviation: "NYJ", name: "New York Jets", slug: "jets", conference: AFC, division: "East", primary_color: "#125740", default_pick_rank: 32, external_id: "134921"},
      # AFC North
      {abbreviation: "BAL", name: "Baltimore Ravens", slug: "ravens", conference: AFC, division: "North", primary_color: "#241773", default_pick_rank: 18, external_id: "134922"},
      {abbreviation: "CIN", name: "Cincinnati Bengals", slug: "bengals", conference: AFC, division: "North", primary_color: "#FB4F14", default_pick_rank: 25, external_id: "134923"},
      {abbreviation: "CLE", name: "Cleveland Browns", slug: "browns", conference: AFC, division: "North", primary_color: "#311D00", default_pick_rank: 27, external_id: "134924"},
      {abbreviation: "PIT", name: "Pittsburgh Steelers", slug: "steelers", conference: AFC, division: "North", primary_color: "#FFB612", default_pick_rank: 12, external_id: "134925"},
      # AFC South
      {abbreviation: "HOU", name: "Houston Texans", slug: "texans", conference: AFC, division: "South", primary_color: "#03202F", default_pick_rank: 6, external_id: "134926"},
      {abbreviation: "IND", name: "Indianapolis Colts", slug: "colts", conference: AFC, division: "South", primary_color: "#002C5F", default_pick_rank: 17, external_id: "134927"},
      {abbreviation: "JAX", name: "Jacksonville Jaguars", slug: "jaguars", conference: AFC, division: "South", primary_color: "#101820", default_pick_rank: 9, external_id: "134928"},
      {abbreviation: "TEN", name: "Tennessee Titans", slug: "titans", conference: AFC, division: "South", primary_color: "#0C2340", default_pick_rank: 31, external_id: "134929"},
      # AFC West
      {abbreviation: "DEN", name: "Denver Broncos", slug: "broncos", conference: AFC, division: "West", primary_color: "#FB4F14", default_pick_rank: 3, external_id: "134930"},
      {abbreviation: "KC", name: "Kansas City Chiefs", slug: "chiefs", conference: AFC, division: "West", primary_color: "#E31837", default_pick_rank: 23, external_id: "134931"},
      {abbreviation: "LV", name: "Las Vegas Raiders", slug: "raiders", conference: AFC, division: "West", primary_color: "#000000", default_pick_rank: 30, external_id: "134932"},
      {abbreviation: "LAC", name: "Los Angeles Chargers", slug: "chargers", conference: AFC, division: "West", primary_color: "#0080C6", default_pick_rank: 11, external_id: "135908"},
      # NFC East
      {abbreviation: "DAL", name: "Dallas Cowboys", slug: "cowboys", conference: NFC, division: "East", primary_color: "#003594", default_pick_rank: 21, external_id: "134934"},
      {abbreviation: "NYG", name: "New York Giants", slug: "giants", conference: NFC, division: "East", primary_color: "#0B2265", default_pick_rank: 28, external_id: "134935"},
      {abbreviation: "PHI", name: "Philadelphia Eagles", slug: "eagles", conference: NFC, division: "East", primary_color: "#004C54", default_pick_rank: 10, external_id: "134936"},
      {abbreviation: "WAS", name: "Washington Commanders", slug: "commanders", conference: NFC, division: "East", primary_color: "#5A1414", default_pick_rank: 26, external_id: "134937"},
      # NFC North
      {abbreviation: "CHI", name: "Chicago Bears", slug: "bears", conference: NFC, division: "North", primary_color: "#0B162A", default_pick_rank: 8, external_id: "134938"},
      {abbreviation: "DET", name: "Detroit Lions", slug: "lions", conference: NFC, division: "North", primary_color: "#0076B6", default_pick_rank: 15, external_id: "134939"},
      {abbreviation: "GB", name: "Green Bay Packers", slug: "packers", conference: NFC, division: "North", primary_color: "#203731", default_pick_rank: 13, external_id: "134940"},
      {abbreviation: "MIN", name: "Minnesota Vikings", slug: "vikings", conference: NFC, division: "North", primary_color: "#4F2683", default_pick_rank: 16, external_id: "134941"},
      # NFC South
      {abbreviation: "ATL", name: "Atlanta Falcons", slug: "falcons", conference: NFC, division: "South", primary_color: "#A71930", default_pick_rank: 20, external_id: "134942"},
      {abbreviation: "CAR", name: "Carolina Panthers", slug: "panthers", conference: NFC, division: "South", primary_color: "#0085CA", default_pick_rank: 14, external_id: "134943"},
      {abbreviation: "NO", name: "New Orleans Saints", slug: "saints", conference: NFC, division: "South", primary_color: "#D3BC8D", default_pick_rank: 24, external_id: "134944"},
      {abbreviation: "TB", name: "Tampa Bay Buccaneers", slug: "buccaneers", conference: NFC, division: "South", primary_color: "#D50A0A", default_pick_rank: 19, external_id: "134945"},
      # NFC West
      {abbreviation: "ARI", name: "Arizona Cardinals", slug: "cardinals", conference: NFC, division: "West", primary_color: "#97233F", default_pick_rank: 29, external_id: "134946"},
      {abbreviation: "LAR", name: "Los Angeles Rams", slug: "rams", conference: NFC, division: "West", primary_color: "#003594", default_pick_rank: 4, external_id: "135907"},
      {abbreviation: "SF", name: "San Francisco 49ers", slug: "niners", conference: NFC, division: "West", primary_color: "#AA0000", default_pick_rank: 7, external_id: "134948"},
      {abbreviation: "SEA", name: "Seattle Seahawks", slug: "seahawks", conference: NFC, division: "West", primary_color: "#002244", default_pick_rank: 1, external_id: "134949"}
    ].freeze
  end
end
