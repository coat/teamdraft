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

  it "hides up arrow for top-ranked team and down arrow for bottom-ranked" do
    sign_in_admin
    sport = create(:sport, :nfl)
    top = create(:team, sport: sport, name: "Top TC", abbreviation: "TP", slug: "top", default_pick_rank: 1)
    middle = create(:team, sport: sport, name: "Middle TC", abbreviation: "MD", slug: "middle", default_pick_rank: 2)
    bottom = create(:team, sport: sport, name: "Bottom TC", abbreviation: "BT", slug: "bottom", default_pick_rank: 3)

    get admin_teams_path

    expect(response).to have_http_status(:ok)

    # Up arrow hidden for top team
    expect(response.body).not_to include(move_up_admin_team_path(top))
    # Down arrow hidden for bottom team
    expect(response.body).not_to include(move_down_admin_team_path(bottom))
    # Both arrows visible for middle team
    expect(response.body).to include(move_up_admin_team_path(middle))
    expect(response.body).to include(move_down_admin_team_path(middle))
  end

  it "hides both arrows for a team with nil rank" do
    sign_in_admin
    sport = create(:sport, :nfl)
    team = create(:team, sport: sport, default_pick_rank: nil)

    get admin_teams_path

    expect(response.body).not_to include(move_up_admin_team_path(team))
    expect(response.body).not_to include(move_down_admin_team_path(team))
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

  describe "move_up" do
    it "swaps rank with the team above" do
      sign_in_admin
      sport = create(:sport, :nfl)
      above = create(:team, sport: sport, name: "Above", abbreviation: "AB", slug: "above", default_pick_rank: 3)
      below = create(:team, sport: sport, name: "Below", abbreviation: "BL", slug: "below", default_pick_rank: 7)

      patch move_up_admin_team_path(below)

      expect(response).to redirect_to(admin_teams_path)
      expect(above.reload.default_pick_rank).to eq(7)
      expect(below.reload.default_pick_rank).to eq(3)
    end

    it "handles gaps between ranks" do
      sign_in_admin
      sport = create(:sport, :nfl)
      create(:team, sport: sport, abbreviation: "T1", slug: "team-1", default_pick_rank: 2)
      middle = create(:team, sport: sport, abbreviation: "T2", slug: "team-2", default_pick_rank: 5)

      patch move_up_admin_team_path(middle)

      expect(response).to redirect_to(admin_teams_path)
      expect(middle.reload.default_pick_rank).to eq(2)
    end

    it "redirects with alert when already at the top" do
      sign_in_admin
      sport = create(:sport, :nfl)
      top = create(:team, sport: sport, default_pick_rank: 1)

      patch move_up_admin_team_path(top)

      expect(response).to redirect_to(admin_teams_path)
      expect(flash[:alert]).to include("already at the top")
      expect(top.reload.default_pick_rank).to eq(1)
    end

    it "redirects with alert when rank is nil" do
      sign_in_admin
      sport = create(:sport, :nfl)
      team = create(:team, sport: sport, default_pick_rank: nil)

      patch move_up_admin_team_path(team)

      expect(response).to redirect_to(admin_teams_path)
      expect(flash[:alert]).to include("without a pick rank")
    end
  end

  describe "move_down" do
    it "swaps rank with the team below" do
      sign_in_admin
      sport = create(:sport, :nfl)
      above = create(:team, sport: sport, name: "Above", abbreviation: "AB", slug: "above", default_pick_rank: 4)
      below = create(:team, sport: sport, name: "Below", abbreviation: "BL", slug: "below", default_pick_rank: 9)

      patch move_down_admin_team_path(above)

      expect(response).to redirect_to(admin_teams_path)
      expect(above.reload.default_pick_rank).to eq(9)
      expect(below.reload.default_pick_rank).to eq(4)
    end

    it "redirects with alert when already at the bottom" do
      sign_in_admin
      sport = create(:sport, :nfl)
      bottom = create(:team, sport: sport, default_pick_rank: 32)

      patch move_down_admin_team_path(bottom)

      expect(response).to redirect_to(admin_teams_path)
      expect(flash[:alert]).to include("already at the bottom")
      expect(bottom.reload.default_pick_rank).to eq(32)
    end

    it "redirects with alert when rank is nil" do
      sign_in_admin
      sport = create(:sport, :nfl)
      team = create(:team, sport: sport, default_pick_rank: nil)

      patch move_down_admin_team_path(team)

      expect(response).to redirect_to(admin_teams_path)
      expect(flash[:alert]).to include("without a pick rank")
    end
  end

  describe "authorization" do
    it "redirects unauthenticated users" do
      sport = create(:sport, :nfl)
      team = create(:team, sport: sport, default_pick_rank: 5)

      patch move_up_admin_team_path(team)

      expect(response).to redirect_to(new_session_path)
    end

    it "redirects non-admin users" do
      user = create(:user, admin: false)
      post session_path, params: {email_address: user.email_address, password: "supersecret"}
      sport = create(:sport, :nfl)
      team = create(:team, sport: sport, default_pick_rank: 5)

      patch move_up_admin_team_path(team)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Admin access required.")
    end
  end
end
