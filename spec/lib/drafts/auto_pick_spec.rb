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

  it "raises StalePick when the draft advanced past the expected pick number" do
    ls = create_drafting_ls
    Drafts::SubmitPick.call(league_season: ls, season_team: ls.season.season_teams.first)

    expect { Drafts::AutoPick.call(league_season: ls.reload, expected_pick_number: 1) }
      .to raise_error(Drafts::SubmitPick::StalePick)
  end

  it "skips already-drafted teams" do
    ls = create_drafting_ls
    ranked = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").to_a
    top, second = ranked[0], ranked[1]
    Drafts::SubmitPick.call(league_season: ls, season_team: top)

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.season_team).to eq(second)
  end

  it "honors the picking user's personal ranking over the global default" do
    ls = create_drafting_ls
    alice = attach_user_to(ls.participants.find_by(draft_position: 1))
    ranked = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").to_a
    favorite = ranked.last
    create(:user_team_ranking, user: alice, team: favorite.team, rank: 1)

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.season_team).to eq(favorite)
  end

  it "falls through to global ranking when the user's top picks are taken" do
    ls = create_drafting_ls
    alice = attach_user_to(ls.participants.find_by(draft_position: 1))
    ranked = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").to_a
    user_top = ranked.last
    Drafts::SubmitPick.call(league_season: ls, season_team: user_top)
    create(:user_team_ranking, user: alice, team: user_top.team, rank: 1)
    # Alice (pos 1) is on the clock again at pick 3 in linear order? No - size 2 linear cycles 1,2,1,2.
    # Pick 2 belongs to Bob; advance through it manually before testing Alice's autopick.
    Drafts::SubmitPick.call(league_season: ls, season_team: ranked[2])

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.season_team).to eq(ranked.first)
  end

  it "respects sport scoping (rankings in another sport do not bleed in)" do
    ls = create_drafting_ls
    alice = attach_user_to(ls.participants.find_by(draft_position: 1))
    other_sport = create(:sport, :nba)
    other_team = create(:team, sport: other_sport)
    create(:user_team_ranking, user: alice, team: other_team, rank: 1)
    expected = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").first

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.season_team).to eq(expected)
  end

  it "uses each user's own rankings across consecutive autopicks" do
    ls = create_drafting_ls
    alice = attach_user_to(ls.participants.find_by(draft_position: 1))
    bob = attach_user_to(ls.participants.find_by(draft_position: 2))
    ranked = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").to_a
    create(:user_team_ranking, user: alice, team: ranked.last.team, rank: 1)
    create(:user_team_ranking, user: bob, team: ranked[2].team, rank: 1)

    Drafts::AutoPick.call(league_season: ls)
    Drafts::AutoPick.call(league_season: ls.reload)

    expect(ls.draft_picks.order(:pick_number).map(&:season_team)).to eq([ranked.last, ranked[2]])
  end

  it "falls back to global ordering for an unclaimed seat" do
    ls = create_drafting_ls
    ls.participants.find_by(draft_position: 1).update!(user_id: nil)
    expected = ls.season.season_teams.joins(:team).order("teams.default_pick_rank").first

    Drafts::AutoPick.call(league_season: ls)

    expect(ls.draft_picks.last.season_team).to eq(expected)
  end

  def attach_user_to(participant)
    user = create(:user)
    participant.update!(user: user)
    user
  end

  def create_drafting_ls
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season)
    start_drafting!(ls)
  end
end
