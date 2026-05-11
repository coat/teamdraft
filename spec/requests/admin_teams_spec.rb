# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin teams", type: :request do
  it "lists all teams" do
    sign_in_admin
    sport = create(:sport, :nfl)
    create(:team, sport: sport, name: "Kansas City Chiefs", abbreviation: "KC", slug: "chiefs")

    get admin_teams_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Kansas City Chiefs")
  end

  it "updates external_id and default_pick_rank" do
    sign_in_admin
    sport = create(:sport, :nfl)
    team = create(:team, sport: sport, default_pick_rank: 10)

    patch admin_team_path(team), params: {
      team: {external_id: "TSDB-12345", default_pick_rank: 2, name: team.name, abbreviation: team.abbreviation}
    }

    expect(response).to redirect_to(admin_teams_path)
    expect(team.reload.external_id).to eq("TSDB-12345")
    expect(team.default_pick_rank).to eq(2)
  end
end
