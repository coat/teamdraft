# frozen_string_literal: true

require "rails_helper"

RSpec.describe Leagues::DirectoryQuery do
  describe "defaults" do
    it "defaults to rank/asc + available when the league is drafting" do
      ls = drafting_league_season

      query = described_class.new(league_season: ls, params: {})

      expect(query.sort_column).to eq("rank")
      expect(query.sort_dir).to eq("asc")
      expect(query.status).to eq("available")
    end

    it "defaults to points/desc + all teams when the draft is finished" do
      ls = drafting_league_season
      ls.update!(status: "in_season")

      query = described_class.new(league_season: ls, params: {})

      expect(query.sort_column).to eq("points")
      expect(query.sort_dir).to eq("desc")
      expect(query.status).to eq("")
    end

    it "honors an explicit empty status (user picked 'All')" do
      ls = drafting_league_season

      query = described_class.new(league_season: ls, params: {status: ""})

      expect(query.status).to eq("")
    end
  end

  describe "whitelisting" do
    it "rejects unknown sort columns" do
      ls = drafting_league_season

      query = described_class.new(league_season: ls, params: {sort: "haxor"})

      expect(query.sort_column).to eq("rank")
    end

    it "rejects malformed status tokens" do
      ls = drafting_league_season

      query = described_class.new(league_season: ls, params: {status: "p:notanint"})

      expect(query.status).to eq("")
    end
  end

  describe "filters" do
    it "returns only available rows when status=available" do
      ls = drafting_league_season
      Drafts::SubmitPick.call(league_season: ls, season_team: ls.season.season_teams.first)

      rows = described_class.new(league_season: ls, params: {status: "available"}).rows

      expect(rows.size).to eq(ls.season.season_teams.count - 1)
      expect(rows.none? { |r| r.pick }).to be(true)
    end

    it "returns only that participant's rows when status=p:<id>" do
      ls = drafting_league_season
      Drafts::SubmitPick.call(league_season: ls, season_team: ls.season.season_teams.first)
      participant = ls.draft_picks.first.participant

      rows = described_class.new(league_season: ls,
        params: {status: "p:#{participant.id}"}).rows

      expect(rows.size).to eq(1)
      expect(rows.first.pick.participant_id).to eq(participant.id)
    end
  end

  describe "sorting" do
    it "sorts by name desc when requested" do
      ls = drafting_league_season

      rows = described_class.new(league_season: ls,
        params: {status: "", sort: "name", dir: "desc"}).rows

      expect(rows.first.team.name).to eq("Team 4")
      expect(rows.last.team.name).to eq("Team 1")
    end

    it "sorts by pick asc with picked rows first" do
      ls = drafting_league_season
      Drafts::SubmitPick.call(league_season: ls, season_team: ls.season.season_teams.last)

      rows = described_class.new(league_season: ls,
        params: {status: "", sort: "pick", dir: "asc"}).rows

      expect(rows.first.pick).to be_present
      expect(rows.drop(1).all? { |r| r.pick.nil? }).to be(true)
    end
  end

  describe "#to_url_params" do
    it "drops empty values and honors overrides" do
      ls = drafting_league_season

      query = described_class.new(league_season: ls, params: {sort: "name", dir: "asc"})

      expect(query.to_url_params(dir: "desc")).to eq(
        sort: "name", dir: "desc", status: "available"
      )
    end
  end

  describe "mid-season drafts (scoring events already exist)" do
    it "reports any_scoring_events? true when the season has any events" do
      ls = drafting_league_season
      ScoringEvent.create!(season_team: ls.season.season_teams.first,
        event_type: "regular_win", occurred_at: Time.current)

      query = Leagues::DirectoryQuery.new(league_season: ls, params: {})

      expect(query.any_scoring_events?).to be(true)
    end

    it "defaults sort to points/desc while drafting when events exist" do
      ls = drafting_league_season
      ScoringEvent.create!(season_team: ls.season.season_teams.first,
        event_type: "regular_win", occurred_at: Time.current)

      query = Leagues::DirectoryQuery.new(league_season: ls, params: {})

      expect(query.sort_column).to eq("points")
      expect(query.sort_dir).to eq("desc")
    end

    it "keeps default sort as rank when no events exist yet" do
      ls = drafting_league_season

      query = Leagues::DirectoryQuery.new(league_season: ls, params: {})

      expect(query.any_scoring_events?).to be(false)
      expect(query.sort_column).to eq("rank")
    end

    it "breaks points ties by team default_pick_rank (lower rank first)" do
      # create_nfl_season assigns default_pick_rank 1..N in season_teams order.
      ls = drafting_league_season
      teams = ls.season.season_teams.to_a
      # Give the 2nd and 3rd team equal points; 3rd has higher (worse) rank.
      ScoringEvent.create!(season_team: teams[1], event_type: "regular_win",
        occurred_at: Time.current)
      ScoringEvent.create!(season_team: teams[2], event_type: "regular_win",
        occurred_at: Time.current)

      rows = Leagues::DirectoryQuery.new(league_season: ls,
        params: {status: "", sort: "points", dir: "desc"}).rows

      tied_rows = rows.select { |r| r.points == 1 }
      expect(tied_rows.map { |r| r.team.default_pick_rank }).to eq([2, 3])
    end
  end

  def drafting_league_season
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season)
    start_drafting!(ls)
  end
end
