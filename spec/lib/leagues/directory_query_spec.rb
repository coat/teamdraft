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

    it "defaults to pick/asc + all teams when the draft is finished" do
      ls = drafting_league_season
      ls.update!(status: "in_season")

      query = described_class.new(league_season: ls, params: {})

      expect(query.sort_column).to eq("pick")
      expect(query.sort_dir).to eq("asc")
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

  def drafting_league_season
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season)
    start_drafting!(ls)
  end
end
