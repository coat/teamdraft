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
end
