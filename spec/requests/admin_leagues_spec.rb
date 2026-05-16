# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin leagues", type: :request do
  it "lists all leagues with status badges" do
    sign_in_admin
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport, year: 2026, label: "NFL 2026")
    league = create(:league, name: "Touchdown Tuesday")
    create(:league_season, league: league, season: season, status: "drafting")

    get admin_leagues_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Touchdown Tuesday")
    expect(response.body).to include("drafting")
    expect(response.body).to include("NFL 2026")
  end

  it "flags anonymous leagues (no participants linked to users)" do
    sign_in_admin
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    league = create(:league, name: "Ghost League")
    create(:league_season, :with_two_participants, league: league, season: season)

    get admin_leagues_path

    expect(response.body).to include("Ghost League")
    expect(response.body).to include("anonymous")
  end

  it "shows a signed-up badge when a participant has a user" do
    sign_in_admin
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    user = create(:user)
    league = create(:league, name: "Real Users League")
    ls = create(:league_season, :with_two_participants, league: league, season: season)
    ls.participants.first.update!(user: user)

    get admin_leagues_path

    expect(response.body).to include("Real Users League")
    expect(response.body).to include("1/2 signed up")
  end

  it "force-updates LeagueSeason status via update" do
    sign_in_admin
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    league = create(:league)
    ls = create(:league_season, league: league, season: season, status: "draft_pending")

    patch admin_league_path(league), params: {
      league: {name: league.name},
      league_season: {
        size: ls.size,
        draft_mode: ls.draft_mode, draft_order_style: ls.draft_order_style,
        current_pick_number: ls.current_pick_number,
        status: "completed"
      }
    }

    expect(response).to redirect_to(admin_leagues_path)
    expect(ls.reload.status).to eq("completed")
  end

  it "destroys the league and cascades to participants + draft_picks" do
    sign_in_admin
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    league = create(:league)
    ls = create(:league_season, :with_two_participants, league: league, season: season)
    participant_ids = ls.participants.pluck(:id)

    expect {
      delete admin_league_path(league)
    }.to change(League, :count).by(-1)

    expect(response).to redirect_to(admin_leagues_path)
    expect(Participant.where(id: participant_ids)).to be_empty
  end

  it "requires admin to access" do
    create(:league)

    get admin_leagues_path

    expect(response).to redirect_to(new_session_path)
  end
end
