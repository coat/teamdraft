# frozen_string_literal: true

require "rails_helper"

RSpec.describe Seasons::PopulateTeams do
  it "attaches a SeasonTeam for every team in the sport" do
    sport = create(:sport, :nfl)
    create(:team, sport: sport)
    create(:team, sport: sport)
    create(:team, sport: sport)
    season = create(:season, sport: sport)

    Seasons::PopulateTeams.call(season: season)

    expect(season.season_teams.count).to eq(3)
    expect(season.teams).to match_array(sport.teams)
  end

  it "ignores teams from other sports" do
    nfl = create(:sport, :nfl)
    other = create(:sport)
    create(:team, sport: nfl)
    create(:team, sport: other)
    season = create(:season, sport: nfl)

    Seasons::PopulateTeams.call(season: season)

    expect(season.season_teams.count).to eq(1)
    expect(season.teams.first.sport_id).to eq(nfl.id)
  end

  it "is idempotent across repeated runs" do
    sport = create(:sport, :nfl)
    create(:team, sport: sport)
    create(:team, sport: sport)
    season = create(:season, sport: sport)

    Seasons::PopulateTeams.call(season: season)
    Seasons::PopulateTeams.call(season: season)

    expect(season.season_teams.count).to eq(2)
  end

  it "adds rows for newly-added teams when re-run" do
    sport = create(:sport, :nfl)
    create(:team, sport: sport)
    season = create(:season, sport: sport)
    Seasons::PopulateTeams.call(season: season)
    create(:team, sport: sport)

    Seasons::PopulateTeams.call(season: season)

    expect(season.season_teams.count).to eq(2)
  end
end
