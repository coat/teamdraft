# frozen_string_literal: true

# Static fixture for the 32 NFL teams. Used by db/seeds.rb.

module Seeds
  module NflTeams
    AFC = "AFC"
    NFC = "NFC"

    # default_pick_rank: 1 = first auto-pick when AFK, 32 = last resort.
    # Editable by admins later; this is just a defensible starting point.
    DATA = [
      # AFC East
      {abbreviation: "BUF", name: "Buffalo Bills", slug: "bills", conference: AFC, division: "East", primary_color: "#00338D", default_pick_rank: 5},
      {abbreviation: "MIA", name: "Miami Dolphins", slug: "dolphins", conference: AFC, division: "East", primary_color: "#008E97", default_pick_rank: 22},
      {abbreviation: "NE", name: "New England Patriots", slug: "patriots", conference: AFC, division: "East", primary_color: "#002244", default_pick_rank: 2},
      {abbreviation: "NYJ", name: "New York Jets", slug: "jets", conference: AFC, division: "East", primary_color: "#125740", default_pick_rank: 32},
      # AFC North
      {abbreviation: "BAL", name: "Baltimore Ravens", slug: "ravens", conference: AFC, division: "North", primary_color: "#241773", default_pick_rank: 18},
      {abbreviation: "CIN", name: "Cincinnati Bengals", slug: "bengals", conference: AFC, division: "North", primary_color: "#FB4F14", default_pick_rank: 25},
      {abbreviation: "CLE", name: "Cleveland Browns", slug: "browns", conference: AFC, division: "North", primary_color: "#311D00", default_pick_rank: 27},
      {abbreviation: "PIT", name: "Pittsburgh Steelers", slug: "steelers", conference: AFC, division: "North", primary_color: "#FFB612", default_pick_rank: 12},
      # AFC South
      {abbreviation: "HOU", name: "Houston Texans", slug: "texans", conference: AFC, division: "South", primary_color: "#03202F", default_pick_rank: 6},
      {abbreviation: "IND", name: "Indianapolis Colts", slug: "colts", conference: AFC, division: "South", primary_color: "#002C5F", default_pick_rank: 17},
      {abbreviation: "JAX", name: "Jacksonville Jaguars", slug: "jaguars", conference: AFC, division: "South", primary_color: "#101820", default_pick_rank: 9},
      {abbreviation: "TEN", name: "Tennessee Titans", slug: "titans", conference: AFC, division: "South", primary_color: "#0C2340", default_pick_rank: 31},
      # AFC West
      {abbreviation: "DEN", name: "Denver Broncos", slug: "broncos", conference: AFC, division: "West", primary_color: "#FB4F14", default_pick_rank: 3},
      {abbreviation: "KC", name: "Kansas City Chiefs", slug: "chiefs", conference: AFC, division: "West", primary_color: "#E31837", default_pick_rank: 23},
      {abbreviation: "LV", name: "Las Vegas Raiders", slug: "raiders", conference: AFC, division: "West", primary_color: "#000000", default_pick_rank: 30},
      {abbreviation: "LAC", name: "Los Angeles Chargers", slug: "chargers", conference: AFC, division: "West", primary_color: "#0080C6", default_pick_rank: 11},
      # NFC East
      {abbreviation: "DAL", name: "Dallas Cowboys", slug: "cowboys", conference: NFC, division: "East", primary_color: "#003594", default_pick_rank: 21},
      {abbreviation: "NYG", name: "New York Giants", slug: "giants", conference: NFC, division: "East", primary_color: "#0B2265", default_pick_rank: 28},
      {abbreviation: "PHI", name: "Philadelphia Eagles", slug: "eagles", conference: NFC, division: "East", primary_color: "#004C54", default_pick_rank: 10},
      {abbreviation: "WAS", name: "Washington Commanders", slug: "commanders", conference: NFC, division: "East", primary_color: "#5A1414", default_pick_rank: 26},
      # NFC North
      {abbreviation: "CHI", name: "Chicago Bears", slug: "bears", conference: NFC, division: "North", primary_color: "#0B162A", default_pick_rank: 8},
      {abbreviation: "DET", name: "Detroit Lions", slug: "lions", conference: NFC, division: "North", primary_color: "#0076B6", default_pick_rank: 15},
      {abbreviation: "GB", name: "Green Bay Packers", slug: "packers", conference: NFC, division: "North", primary_color: "#203731", default_pick_rank: 13},
      {abbreviation: "MIN", name: "Minnesota Vikings", slug: "vikings", conference: NFC, division: "North", primary_color: "#4F2683", default_pick_rank: 16},
      # NFC South
      {abbreviation: "ATL", name: "Atlanta Falcons", slug: "falcons", conference: NFC, division: "South", primary_color: "#A71930", default_pick_rank: 20},
      {abbreviation: "CAR", name: "Carolina Panthers", slug: "panthers", conference: NFC, division: "South", primary_color: "#0085CA", default_pick_rank: 14},
      {abbreviation: "NO", name: "New Orleans Saints", slug: "saints", conference: NFC, division: "South", primary_color: "#D3BC8D", default_pick_rank: 24},
      {abbreviation: "TB", name: "Tampa Bay Buccaneers", slug: "buccaneers", conference: NFC, division: "South", primary_color: "#D50A0A", default_pick_rank: 19},
      # NFC West
      {abbreviation: "ARI", name: "Arizona Cardinals", slug: "cardinals", conference: NFC, division: "West", primary_color: "#97233F", default_pick_rank: 29},
      {abbreviation: "LAR", name: "Los Angeles Rams", slug: "rams", conference: NFC, division: "West", primary_color: "#003594", default_pick_rank: 4},
      {abbreviation: "SF", name: "San Francisco 49ers", slug: "niners", conference: NFC, division: "West", primary_color: "#AA0000", default_pick_rank: 7},
      {abbreviation: "SEA", name: "Seattle Seahawks", slug: "seahawks", conference: NFC, division: "West", primary_color: "#002244", default_pick_rank: 1}
    ].freeze
  end
end
