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

  describe "filtering and sorting" do
    it "filters by the q param" do
      sign_in_admin
      sport = create(:sport, :nfl)
      season_a = create(:season, sport: sport, year: 2040)
      season_b = create(:season, sport: sport, year: 2041)
      create(:league_season, league: create(:league, name: "Ravens Roost"), season: season_a)
      create(:league_season, league: create(:league, name: "Eagle Eyes"), season: season_b)

      get admin_leagues_path, params: {q: "raven"}

      expect(response.body).to include("Ravens Roost")
      expect(response.body).not_to include("Eagle Eyes")
    end

    it "filters by status" do
      sign_in_admin
      sport = create(:sport, :nfl)
      season_a = create(:season, sport: sport, year: 2040)
      season_b = create(:season, sport: sport, year: 2041)
      create(:league_season, league: create(:league, name: "Active Now"), season: season_a, status: "drafting")
      create(:league_season, league: create(:league, name: "Finished"), season: season_b, status: "completed")

      get admin_leagues_path, params: {status: "drafting"}

      expect(response.body).to include("Active Now")
      expect(response.body).not_to include("Finished")
    end

    it "shows the empty state when no leagues match" do
      sign_in_admin

      get admin_leagues_path, params: {q: "nope"}

      expect(response.body).to include("No leagues match these filters.")
    end

    it "preserves the search term in the filter input" do
      sign_in_admin

      get admin_leagues_path, params: {q: "alice"}

      expect(response.body).to include('value="alice"')
    end

    it "paginates when more leagues exist than the page size" do
      sign_in_admin
      sport = create(:sport, :nfl)
      seasons = 27.times.map { |i| create(:season, sport: sport, year: 2050 + i) }
      seasons.each_with_index do |season, i|
        create(:league_season, league: create(:league, name: "League %02d" % i), season: season)
      end

      get admin_leagues_path

      expect(response.body).to include("League 00")
      expect(response.body).not_to include("League 26")

      get admin_leagues_path, params: {page: 2}

      expect(response.body).to include("League 26")
    end
  end

  it "requires admin to access" do
    create(:league)

    get admin_leagues_path

    expect(response).to redirect_to(new_session_path)
  end
end
