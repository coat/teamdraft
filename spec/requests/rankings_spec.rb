# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rankings", type: :request do
  it "redirects unauthenticated visitors to sign in" do
    get rankings_path

    expect(response).to redirect_to(new_session_path)
  end

  it "shows the sport picker for signed-in users" do
    create(:sport, :nfl)
    sign_in_new_user("alice@example.com")

    get rankings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("My Rankings")
    expect(response.body).to include("NFL")
  end

  it "lists ranked and unranked teams for the sport" do
    sport = create(:sport, :nfl)
    ranked_team = create(:team, sport: sport, name: "Alpha", default_pick_rank: 1)
    unranked_team = create(:team, sport: sport, name: "Beta", default_pick_rank: 2)
    user = sign_in_new_user("alice@example.com")
    create(:user_team_ranking, user: user, team: ranked_team, rank: 1)

    get sport_rankings_path(sport.key)

    expect(response.body).to include("Alpha")
    expect(response.body).to include("Beta")
  end

  it "appends a team via create" do
    sport = create(:sport, :nfl)
    team = create(:team, sport: sport)
    user = sign_in_new_user("alice@example.com")

    post sport_rankings_create_path(sport.key), params: {team_id: team.id}

    ranking = user.team_rankings.find_by(team: team)
    expect(ranking.rank).to eq(1)
  end

  it "appends new entries at the bottom of the list" do
    sport = create(:sport, :nfl)
    first = create(:team, sport: sport)
    second = create(:team, sport: sport)
    user = sign_in_new_user("alice@example.com")
    create(:user_team_ranking, user: user, team: first, rank: 1)

    post sport_rankings_create_path(sport.key), params: {team_id: second.id}

    expect(user.team_rankings.find_by(team: second).rank).to eq(2)
  end

  it "swaps positions on move_up" do
    sport = create(:sport, :nfl)
    a = create(:team, sport: sport)
    b = create(:team, sport: sport)
    user = sign_in_new_user("alice@example.com")
    create(:user_team_ranking, user: user, team: a, rank: 1)
    b_rank = create(:user_team_ranking, user: user, team: b, rank: 2)

    patch move_up_sport_ranking_path(sport.key, b_rank)

    ranks = user.team_rankings.order(:rank).pluck(:team_id, :rank)
    expect(ranks).to eq([[b.id, 1], [a.id, 2]])
  end

  it "rejects move_up at the top boundary" do
    sport = create(:sport, :nfl)
    team = create(:team, sport: sport)
    user = sign_in_new_user("alice@example.com")
    top = create(:user_team_ranking, user: user, team: team, rank: 1)

    patch move_up_sport_ranking_path(sport.key, top)

    expect(top.reload.rank).to eq(1)
    expect(flash[:alert]).to include("already first")
  end

  it "compacts ranks on destroy" do
    sport = create(:sport, :nfl)
    a = create(:team, sport: sport)
    b = create(:team, sport: sport)
    c = create(:team, sport: sport)
    user = sign_in_new_user("alice@example.com")
    middle = create(:user_team_ranking, user: user, team: b, rank: 2)
    create(:user_team_ranking, user: user, team: a, rank: 1)
    create(:user_team_ranking, user: user, team: c, rank: 3)

    delete sport_ranking_path(sport.key, middle)

    ranks = user.team_rankings.order(:rank).pluck(:team_id, :rank)
    expect(ranks).to eq([[a.id, 1], [c.id, 2]])
  end

  it "renders without layout and wraps in a turbo-frame when requested as a frame" do
    sport = create(:sport, :nfl)
    create(:team, sport: sport, name: "Alpha", default_pick_rank: 1)
    sign_in_new_user("alice@example.com")

    get sport_rankings_path(sport.key), headers: {"Turbo-Frame" => "user_rankings"}

    expect(response.body).to include(%(<turbo-frame))
    expect(response.body).to include(%(id="user_rankings"))
    expect(response.body).not_to include("<html")
  end

  it "isolates rankings by sport" do
    nfl = create(:sport, :nfl)
    nba = create(:sport, :nba)
    nfl_team = create(:team, sport: nfl, name: "NFL Team")
    nba_team = create(:team, sport: nba, name: "NBA Team")
    user = sign_in_new_user("alice@example.com")
    create(:user_team_ranking, user: user, team: nfl_team, rank: 1)
    create(:user_team_ranking, user: user, team: nba_team, rank: 1)

    get sport_rankings_path(nfl.key)

    expect(response.body).to include("NFL Team")
    expect(response.body).not_to include("NBA Team")
  end

  def sign_in_new_user(email)
    post registration_path, params: {
      user: {email_address: email, password: "supersecret", password_confirmation: "supersecret"}
    }
    User.find_by!(email_address: email)
  end
end
