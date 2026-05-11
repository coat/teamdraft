# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::AutoPick do
  it "picks the lowest default_pick_rank team that is still available" do
    league = create_drafting_league
    top_team = league.season.season_teams.joins(:team).order("teams.default_pick_rank").first.team

    Drafts::AutoPick.call(league: league)

    expect(league.draft_picks.last.team).to eq(top_team)
  end

  it "skips already-drafted teams" do
    league = create_drafting_league
    ranked = league.season.season_teams.joins(:team).order("teams.default_pick_rank").to_a
    top, second = ranked[0], ranked[1]
    Drafts::SubmitPick.call(league: league, season_team: top)

    Drafts::AutoPick.call(league: league)

    expect(league.draft_picks.last.season_team).to eq(second)
  end

  def create_drafting_league
    season = create_nfl_season(team_count: 4)
    league = create(:league, :with_two_participants, season: season)
    start_drafting!(league)
  end
end
