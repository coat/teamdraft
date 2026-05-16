# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::AutoPick do
  it "picks the lowest default_pick_rank team that is still available" do
    ls = create_drafting_ls
    top_team = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").first.team

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.team).to eq(top_team)
  end

  it "flags the resulting pick as autopicked" do
    ls = create_drafting_ls

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.autopicked).to be(true)
  end

  it "leaves human-driven picks unflagged" do
    ls = create_drafting_ls
    season_team = ls.season.season_teams.first

    Drafts::SubmitPick.call(league_season: ls, season_team: season_team)

    expect(ls.draft_picks.last.autopicked).to be(false)
  end

  it "skips already-drafted teams" do
    ls = create_drafting_ls
    ranked = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").to_a
    top, second = ranked[0], ranked[1]
    Drafts::SubmitPick.call(league_season: ls, season_team: top)

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.season_team).to eq(second)
  end

  def create_drafting_ls
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season)
    start_drafting!(ls)
  end
end
