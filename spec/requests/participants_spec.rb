# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reordering draft participants", type: :request do
  it "lets the owner move a participant down, swapping draft positions" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http  # owner cookie is set on this session
    league_season = league.current_league_season
    owner = league_season.participants.find_by(draft_position: 1)
    opponent = league_season.participants.find_by(draft_position: 2)

    patch move_down_league_participant_path(league, owner)

    expect(response).to redirect_to(edit_league_draft_path(league))
    expect(owner.reload.draft_position).to eq(2)
    expect(opponent.reload.draft_position).to eq(1)
  end

  it "lets the owner move a participant up" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http
    league_season = league.current_league_season
    owner = league_season.participants.find_by(draft_position: 1)
    opponent = league_season.participants.find_by(draft_position: 2)

    patch move_up_league_participant_path(league, opponent)

    expect(owner.reload.draft_position).to eq(2)
    expect(opponent.reload.draft_position).to eq(1)
  end

  it "rejects moving the first seat up with a flash and no change" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http
    league_season = league.current_league_season
    owner = league_season.participants.find_by(draft_position: 1)

    patch move_up_league_participant_path(league, owner)
    follow_redirect!

    expect(response.body).to include("already first")
    expect(owner.reload.draft_position).to eq(1)
  end

  it "rejects moving the last seat down with a flash and no change" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http
    league_season = league.current_league_season
    opponent = league_season.participants.find_by(draft_position: 2)

    patch move_down_league_participant_path(league, opponent)
    follow_redirect!

    expect(response.body).to include("already last")
    expect(opponent.reload.draft_position).to eq(2)
  end

  it "refuses reorder requests from non-owners" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http
    league_season = league.current_league_season
    owner = league_season.participants.find_by(draft_position: 1)

    # Drop the owner cookie so the next request comes in anonymous.
    reset!

    patch move_down_league_participant_path(league, owner)

    expect(response).to redirect_to(league_path(league))
    expect(owner.reload.draft_position).to eq(1)
  end

  it "locks reordering once the draft has started" do
    season = create_nfl_season(team_count: 4)
    league = create_league_via_http
    league_season = league.current_league_season
    owner = league_season.participants.find_by(draft_position: 1)
    DraftPick.create!(league_season: league_season, participant: owner,
      season_team: season.season_teams.first, pick_number: 1)

    patch move_down_league_participant_path(league, owner)
    follow_redirect!

    expect(response.body).to include("Draft has started")
    expect(owner.reload.draft_position).to eq(1)
  end

  it "hides the order section once the draft has started" do
    season = create_nfl_season(team_count: 4)
    league = create_league_via_http
    league_season = league.current_league_season
    owner = league_season.participants.find_by(draft_position: 1)
    DraftPick.create!(league_season: league_season, participant: owner,
      season_team: season.season_teams.first, pick_number: 1)

    get edit_league_draft_path(league)

    expect(response.body).to include("Draft has started")
    expect(response.body).not_to include(move_up_league_participant_path(league, owner))
  end
end
