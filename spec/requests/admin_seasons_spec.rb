# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin seasons", type: :request do
  it "lists all seasons with status badges" do
    sign_in_admin
    sport = create(:sport, :nfl)
    create(:season, sport: sport, year: 2026, label: "NFL 2026", status: "upcoming")

    get admin_seasons_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("NFL 2026")
    expect(response.body).to include("upcoming")
  end

  it "creates a season" do
    sign_in_admin
    sport = create(:sport, :nfl)

    post admin_seasons_path, params: {
      season: {
        sport_id: sport.id, year: 2027, label: "NFL 2027",
        status: "upcoming", external_provider: "thesportsdb", external_id: "4391-2027"
      }
    }

    expect(response).to redirect_to(admin_seasons_path)
    expect(Season.find_by(year: 2027, sport_id: sport.id)).to be_present
  end

  it "updates external_id" do
    sign_in_admin
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport, external_id: nil)

    patch admin_season_path(season), params: {
      season: {external_id: "TSDB-XYZ", year: season.year, label: season.label, sport_id: sport.id, status: season.status}
    }

    expect(response).to redirect_to(admin_seasons_path)
    expect(season.reload.external_id).to eq("TSDB-XYZ")
  end

  it "activates a season and demotes any other active season for the same sport" do
    sign_in_admin
    sport = create(:sport, :nfl)
    previous = create(:season, sport: sport, year: 2025, label: "NFL 2025", status: "active")
    upcoming = create(:season, sport: sport, year: 2026, label: "NFL 2026", status: "upcoming")

    post activate_admin_season_path(upcoming)

    expect(response).to redirect_to(admin_seasons_path)
    expect(upcoming.reload.status).to eq("active")
    expect(previous.reload.status).to eq("completed")
  end

  it "shows a season detail page with the sync panel" do
    sign_in_admin
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport, year: 2024, label: "NFL 2024", status: "completed")

    get admin_season_path(season)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("NFL 2024")
    expect(response.body).to include("Sync")
    expect(response.body).to include("Recompute scoring")
    expect(response.body).to include(%(value="#{admin_season_path(season)}"))
  end

  it "requires admin to access" do
    sport = create(:sport, :nfl)
    create(:season, sport: sport)

    get admin_seasons_path

    expect(response).to redirect_to(new_session_path)
  end
end
