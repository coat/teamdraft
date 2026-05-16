# frozen_string_literal: true

require "rails_helper"

RSpec.describe "League history", type: :request do
  it "lists every LeagueSeason for the league with links" do
    league = League.create!(name: "Touchdown Tuesday", slug: "touchdown-tuesday")
    sport = create(:sport, :nfl)
    s24 = create(:season, sport: sport, year: 2024, status: "completed", label: "NFL 2024")
    s25 = create(:season, sport: sport, year: 2025, status: "active", label: "NFL 2025")
    create(:league_season, league: league, season: s24, status: "completed")
    create(:league_season, league: league, season: s25, status: "drafting")

    get history_league_path(league)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("NFL 2024")
    expect(response.body).to include("NFL 2025")
    expect(response.body).to include(league_season_path(league, year: 2024))
    expect(response.body).to include(league_season_path(league, year: 2025))
  end

  it "renders /leagues/:slug/seasons/:year for a historical season" do
    league = League.create!(name: "Touchdown Tuesday", slug: "touchdown-tuesday")
    sport = create(:sport, :nfl)
    past = create(:season, sport: sport, year: 2024, status: "completed", label: "NFL 2024")
    create(:season, sport: sport, year: 2025, status: "active", label: "NFL 2025")
    create(:league_season, :with_two_participants, league: league, season: past, status: "completed")
    create(:league_season, :with_two_participants, league: league, season: Season.find_by!(year: 2025), status: "drafting")

    get league_season_path(league, year: 2024)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("NFL 2024")
  end
end
