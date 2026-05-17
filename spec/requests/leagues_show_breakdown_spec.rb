# frozen_string_literal: true

require "rails_helper"

RSpec.describe "League show scoring breakdown", type: :request do
  it "renders per-team event labels with points when scoring events exist" do
    season = create_nfl_season(team_count: 2)
    ls = create(:league_season, season: season, status: "in_season")
    alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
    create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
    alice_team = season.season_teams.first
    DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)
    ScoringEvent.create!(season_team: alice_team, event_type: "regular_win", points: 12, occurred_at: Time.current)
    ScoringEvent.create!(season_team: alice_team, event_type: "championship_win", points: 8, occurred_at: Time.current)

    get league_path(ls.league)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Regular-season wins")
    expect(response.body).to include("Super Bowl win")
    expect(response.body).to include("breakdown-#{alice_team.id}")
    expect(response.body).to include(season_team_path(season, slug: alice_team.team.slug))
  end

  it "renders the leaderboard panel above the detailed standings with the leader first" do
    season = create_nfl_season(team_count: 2)
    ls = create(:league_season, season: season, status: "in_season")
    alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
    bob = create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
    alice_team, bob_team = season.season_teams.first(2)
    DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)
    DraftPick.create!(league_season: ls, participant: bob, season_team: bob_team, pick_number: 2)
    ScoringEvent.create!(season_team: bob_team, event_type: "regular_win", points: 7, occurred_at: Time.current)

    get league_path(ls.league)

    standings_idx = response.body.index(">Standings<")
    bob_pos = response.body.index("Bob")
    alice_pos = response.body.index("Alice")
    expect(bob_pos).to be < alice_pos
    expect(bob_pos).to be < standings_idx
  end

  it "does not highlight any leader when everyone is at zero" do
    season = create_nfl_season(team_count: 2)
    ls = create(:league_season, season: season, status: "in_season")
    alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
    bob = create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
    alice_team, bob_team = season.season_teams.first(2)
    DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)
    DraftPick.create!(league_season: ls, participant: bob, season_team: bob_team, pick_number: 2)

    get league_path(ls.league)

    leaderboard_section = response.body[0, response.body.index(">Standings<")]
    expect(leaderboard_section).not_to include("badge-warning")
    expect(leaderboard_section).not_to include("border-warning")
  end

  it "hides the Participants panel and shows you/owner badges in standings once the draft is done" do
    season = create_nfl_season(team_count: 2)
    ls = create(:league_season, season: season, status: "in_season")
    alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
    create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
    alice_team = season.season_teams.first
    DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)

    get league_path(ls.league)

    expect(response.body).not_to match(/<h2[^>]*>Participants<\/h2>/)
    expect(response.body).to include("Standings")
    expect(response.body).to include("owner")
  end

  it "still renders the breakdown toggle (with 'No scoring yet.') for picked teams at zero points" do
    season = create_nfl_season(team_count: 2)
    ls = create(:league_season, season: season, status: "in_season")
    alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
    create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
    alice_team = season.season_teams.first
    DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)

    get league_path(ls.league)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("breakdown-#{alice_team.id}")
    expect(response.body).to include("No scoring yet.")
  end
end
