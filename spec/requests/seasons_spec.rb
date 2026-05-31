# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Seasons", type: :request do
  it "lists all seasons on the index" do
    sport = create(:sport, :nfl)
    create(:season, sport: sport, year: 2025, label: "NFL 2025", status: "completed")
    create(:season, sport: sport, year: 2026, label: "NFL 2026", status: "active")

    get seasons_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("NFL 2025")
    expect(response.body).to include("NFL 2026")
  end

  it "shows teams and public leagues on the season page" do
    season = create_nfl_season(team_count: 4)
    create(:league_season, season: season, league: create(:league, name: "Public League"))

    get season_path(season)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Teams")
    expect(response.body).to include("Public League")
    expect(response.body).to include(season.season_teams.first.team.name)
  end

  it "renders sortable column headers, team swatch, and disclosure rows on the season show page" do
    season = create_nfl_season(team_count: 4)

    get season_path(season)

    expect(response.body).to include("sort=points")
    expect(response.body).to include("sort=name")
    expect(response.body).to include("sort=record")
    expect(response.body).to include("sort=division")
    expect(response.body).not_to include("sort=reg&")
    expect(response.body).not_to include("sort=playoffs&")
    expect(response.body).to match(/inline-flex h-7 w-7|logo/)
    expect(response.body).to include('data-controller="disclosure"')
  end

  it "respects the sort param on the season show page" do
    season = create_nfl_season(team_count: 4)

    get season_path(season, sort: "name", dir: "asc")

    expect(response).to have_http_status(:ok)
    sorted_names = season.season_teams.map { |st| st.team.name }.sort
    positions = sorted_names.map { |n| response.body.index(n) }
    expect(positions).to eq(positions.sort)
  end
end
