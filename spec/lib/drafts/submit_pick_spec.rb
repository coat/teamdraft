# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::SubmitPick do
  it "records pick #1 to draft_position 1 and increments the clock" do
    league = create_drafting_league(team_count: 4)
    season_team = league.season.season_teams.first

    result = Drafts::SubmitPick.call(league: league, season_team: season_team)

    expect(result.pick.pick_number).to eq(1)
    expect(result.pick.participant.draft_position).to eq(1)
    expect(result.league.current_pick_number).to eq(2)
    expect(result.league.status).to eq("drafting")
  end

  it "rejects re-drafting the same season_team" do
    league = create_drafting_league(team_count: 4)
    st = league.season.season_teams.first
    Drafts::SubmitPick.call(league: league, season_team: st)

    expect { Drafts::SubmitPick.call(league: league, season_team: st) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it "transitions to in_season after the final pick" do
    league = create_drafting_league(team_count: 4)
    teams = league.season.season_teams.to_a

    teams.each { |st| Drafts::SubmitPick.call(league: league, season_team: st) }

    expect(league.reload.status).to eq("in_season")
    expect(league.draft_completed_at).to be_present
  end

  it "rejects picks while the league is still in draft_pending" do
    league = create(:league, :with_two_participants, season: create_nfl_season(team_count: 4))
    season_team = league.season.season_teams.first

    expect { Drafts::SubmitPick.call(league: league, season_team: season_team) }
      .to raise_error(ActiveRecord::RecordInvalid, /not in progress/)
  end

  def create_drafting_league(team_count:)
    season = create_nfl_season(team_count: team_count)
    league = create(:league, :with_two_participants, season: season)
    start_drafting!(league)
  end
end
