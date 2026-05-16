# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams", type: :request do
  it "renders a team's weekly results with a W badge for a final win" do
    season = create_nfl_season(team_count: 2)
    chiefs_st, broncos_st = season.season_teams.first(2)
    create(:game, :final,
      season: season, week: 5, round: "regular_season",
      home_season_team: chiefs_st, away_season_team: broncos_st,
      home_score: 27, away_score: 14)

    get season_team_path(season, slug: chiefs_st.team.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(chiefs_st.team.name)
    expect(response.body).to include("Week")
    expect(response.body).to match(/>5</)
    expect(response.body).to include("27–14")
    expect(response.body).to include("badge-success")
  end

  it "labels playoff games with the round name and no week number" do
    season = create_nfl_season(team_count: 2)
    a, b = season.season_teams.first(2)
    create(:game, :final,
      season: season, week: nil, round: "wildcard",
      home_season_team: a, away_season_team: b,
      home_score: 21, away_score: 17)

    get season_team_path(season, slug: a.team.slug)

    expect(response.body).to include("Wild Card")
  end

  it "shows a dash for games that have not been played yet" do
    season = create_nfl_season(team_count: 2)
    a, b = season.season_teams.first(2)
    create(:game, season: season, week: 1, round: "regular_season",
      home_season_team: a, away_season_team: b, status: "scheduled")

    get season_team_path(season, slug: a.team.slug)

    expect(response.body).to include("scheduled")
    expect(response.body).to include("—")
  end
end
