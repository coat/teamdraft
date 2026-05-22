# frozen_string_literal: true

# Builders that compose factories into the chunks specs actually need:
# a season plus a fully populated SeasonTeam roster. Most draft/scoring
# specs only care that *some* teams exist for the season, not which
# specific teams - so they call `create_nfl_season` and move on.
#
# NFL-keyed because LeaguesController hard-codes that key when picking a
# default season; non-NFL specs can use raw factories instead.
module SeasonHelpers
  def create_nfl_season(team_count: 4, **season_attrs)
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport, **season_attrs)
    team_count.times do |i|
      team = create(:team, sport: sport, default_pick_rank: i + 1)
      create(:season_team, season: season, team: team)
    end
    season.reload
  end
end

RSpec.configure do |config|
  config.include SeasonHelpers
end
