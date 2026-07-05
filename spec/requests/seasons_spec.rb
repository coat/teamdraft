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

  describe "hierarchical URLs" do
    it "serves the season at /seasons/:sport_key/:year" do
      season = create_nfl_season(team_count: 2)

      get "/seasons/nfl/#{season.year}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(season.label)
    end

    it "generates the hierarchical path from season_path" do
      season = create_nfl_season(team_count: 2)

      expect(season_path(season)).to eq("/seasons/nfl/#{season.year}")
    end

    it "404s for an unknown sport key" do
      season = create_nfl_season(team_count: 2)

      get "/seasons/nope/#{season.year}"

      expect(response).to have_http_status(:not_found)
    end

    it "404s for a year with no season" do
      create_nfl_season(team_count: 2, year: 2025)

      get "/seasons/nfl/1999"

      expect(response).to have_http_status(:not_found)
    end

    it "301-redirects a mixed-case sport key to the canonical lowercase path" do
      season = create_nfl_season(team_count: 2)

      get "/seasons/NFL/#{season.year}"

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/seasons/nfl/#{season.year}")
    end
  end

  describe "legacy numeric URLs" do
    it "301-redirects /seasons/:id to the canonical URL, preserving query params" do
      season = create_nfl_season(team_count: 2)

      get "/seasons/#{season.id}?sort=name"

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/seasons/nfl/#{season.year}?sort=name")
    end

    it "404s for a missing legacy id" do
      get "/seasons/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "standings views" do
    it "defaults to the standings table with a link to the division view" do
      season = create_nfl_season(team_count: 4)

      get season_path(season)

      expect(response.body).to include("sort=division")
      expect(response.body).to include("view=division")
    end

    it "shows teams grouped by division when view=division" do
      season = create_nfl_season(team_count: 2)
      season.season_teams.first.team.update!(conference: "AFC", division: "West")

      get season_path(season, view: "division")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AFC West")
      expect(response.body).not_to include("sort=division")
    end

    it "keeps the division view active in sortable header links" do
      season = create_nfl_season(team_count: 2)

      get season_path(season, view: "division")

      expect(response.body).to match(/sort=name[^"]*view=division|view=division[^"]*sort=name/)
    end

    it "wraps the teams tab in a turbo frame so sorting swaps in place" do
      season = create_nfl_season(team_count: 2)

      get season_path(season)

      expect(response.body).to include('<turbo-frame id="season_teams"')
    end

    it "sends team links to the full page from inside the frame" do
      season = create_nfl_season(team_count: 2)

      get season_path(season)

      expect(response.body).to include('data-turbo-frame="_top"')
    end

    it "marks the view tab links to advance the URL within the frame" do
      season = create_nfl_season(team_count: 2)

      get season_path(season)

      expect(response.body).to match(/role="tab"[^>]*data-turbo-action="advance"/)
    end

    it "tags disclosure rows with a persistence key" do
      season = create_nfl_season(team_count: 2)

      get season_path(season)

      season_team = season.season_teams.first
      expect(response.body).to include(
        %(data-disclosure-key-value="season-breakdown-#{season_team.id}")
      )
    end

    it "falls back to the standings table for unknown view values" do
      season = create_nfl_season(team_count: 2)

      get season_path(season, view: "bogus")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("sort=division")
    end
  end
end
