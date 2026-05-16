# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Leagues::ListQuery do
  describe "search by name" do
    it "matches case-insensitive substrings" do
      sport = create(:sport, :nfl)
      season = create(:season, sport: sport)
      create(:league_season, league: create(:league, name: "Touchdown Tuesday"), season: season)
      create(:league_season, league: create(:league, name: "Friday Football"), season: season)

      results = described_class.new(q: "TUESDAY").relation

      expect(results.map(&:name)).to contain_exactly("Touchdown Tuesday")
    end

    it "ignores blank search terms" do
      sport = create(:sport, :nfl)
      season = create(:season, sport: sport)
      create(:league_season, league: create(:league, name: "Alpha"), season: season)
      create(:league_season, league: create(:league, name: "Beta"), season: season)

      results = described_class.new(q: "  ").relation

      expect(results.size).to eq(2)
    end
  end

  describe "filter by status" do
    it "returns only leagues with a LeagueSeason in the given status" do
      sport = create(:sport, :nfl)
      drafting_season = create(:season, sport: sport, year: 2024)
      done_season = create(:season, sport: sport, year: 2025)
      drafting = create(:league, name: "Drafting Now")
      done = create(:league, name: "All Done")
      create(:league_season, league: drafting, season: drafting_season, status: "drafting")
      create(:league_season, league: done, season: done_season, status: "completed")

      results = described_class.new(status: "drafting").relation

      expect(results.map(&:name)).to contain_exactly("Drafting Now")
    end

    it "ignores invalid status values" do
      sport = create(:sport, :nfl)
      season = create(:season, sport: sport)
      create(:league_season, league: create(:league, name: "One"), season: season)

      results = described_class.new(status: "garbage").relation

      expect(results.size).to eq(1)
    end
  end

  describe "filter by users" do
    it "returns only leagues with at least one signed-up participant when users=yes" do
      sport = create(:sport, :nfl)
      season_a = create(:season, sport: sport, year: 2030)
      season_b = create(:season, sport: sport, year: 2031)
      anon_league = create(:league, name: "Anon")
      real_league = create(:league, name: "Real")
      create(:league_season, :with_two_participants, league: anon_league, season: season_a)
      ls = create(:league_season, :with_two_participants, league: real_league, season: season_b)
      ls.participants.first.update!(user: create(:user))

      results = described_class.new(users: "yes").relation

      expect(results.map(&:name)).to contain_exactly("Real")
    end

    it "returns only leagues with zero signed-up participants when users=no" do
      sport = create(:sport, :nfl)
      season_a = create(:season, sport: sport, year: 2030)
      season_b = create(:season, sport: sport, year: 2031)
      anon_league = create(:league, name: "Anon")
      real_league = create(:league, name: "Real")
      create(:league_season, :with_two_participants, league: anon_league, season: season_a)
      ls = create(:league_season, :with_two_participants, league: real_league, season: season_b)
      ls.participants.first.update!(user: create(:user))

      results = described_class.new(users: "no").relation

      expect(results.map(&:name)).to contain_exactly("Anon")
    end
  end

  describe "sort" do
    it "sorts by name asc by default" do
      sport = create(:sport, :nfl)
      season = create(:season, sport: sport)
      create(:league_season, league: create(:league, name: "Bravo"), season: season)
      create(:league_season, league: create(:league, name: "Alpha"), season: season)

      results = described_class.new({}).relation.to_a

      expect(results.map(&:name)).to eq(%w[Alpha Bravo])
    end

    it "sorts by created_at desc when requested" do
      sport = create(:sport, :nfl)
      season_a = create(:season, sport: sport, year: 2030)
      season_b = create(:season, sport: sport, year: 2031)
      older = create(:league, name: "Older", created_at: 1.day.ago)
      newer = create(:league, name: "Newer", created_at: 1.minute.ago)
      create(:league_season, league: older, season: season_a)
      create(:league_season, league: newer, season: season_b)

      results = described_class.new(sort: "created_at", dir: "desc").relation.to_a

      expect(results.map(&:name)).to eq(%w[Newer Older])
    end

    it "falls back to defaults on unknown sort/dir" do
      query = described_class.new(sort: "bogus", dir: "sideways")

      expect(query.sort_column).to eq("name")
      expect(query.sort_dir).to eq("asc")
    end
  end

  describe "#to_url_params" do
    it "merges overrides and compact_blanks empty filters" do
      query = described_class.new(q: "alice", status: "drafting", sort: "name", dir: "asc")

      url_params = query.to_url_params(sort: "created_at", dir: "desc")

      expect(url_params).to eq(q: "alice", status: "drafting", sort: "created_at", dir: "desc")
    end
  end
end
