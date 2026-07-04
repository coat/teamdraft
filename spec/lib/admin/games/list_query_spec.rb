# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Games::ListQuery do
  def build_game(season, home_idx, away_idx, *traits, **attrs)
    teams = season.season_teams.order(:id).to_a
    create(:game, *traits, season: season,
      home_season_team: teams[home_idx], away_season_team: teams[away_idx], **attrs)
  end

  describe "season resolution" do
    it "uses the season_id param" do
      season = create_nfl_season(year: 2024, status: "completed")
      create(:season, sport: season.sport, year: 2025, status: "active")

      expect(described_class.new(season_id: season.id).season).to eq(season)
    end

    it "falls back to the active season" do
      sport = create(:sport, :nfl)
      create(:season, sport: sport, year: 2024, status: "completed")
      active = create(:season, sport: sport, year: 2025, status: "active")

      expect(described_class.new({}).season).to eq(active)
    end

    it "falls back to the first season when none are active" do
      first = create_nfl_season(year: 2024, status: "completed")

      expect(described_class.new({}).season).to eq(first)
    end

    it "returns no games when no seasons exist" do
      expect(described_class.new({}).relation).to be_empty
    end
  end

  describe "filter by status" do
    it "returns only games with the given status" do
      season = create_nfl_season
      build_game(season, 0, 1, :final)
      scheduled = build_game(season, 2, 3, status: "scheduled")

      results = described_class.new(season_id: season.id, status: "scheduled").relation

      expect(results).to contain_exactly(scheduled)
    end

    it "ignores invalid status values" do
      season = create_nfl_season
      build_game(season, 0, 1)

      results = described_class.new(season_id: season.id, status: "garbage").relation

      expect(results.size).to eq(1)
    end
  end

  describe "filter by round" do
    it "returns only games in the given round" do
      season = create_nfl_season
      build_game(season, 0, 1, round: "regular_season")
      wildcard = build_game(season, 2, 3, round: "wildcard")

      results = described_class.new(season_id: season.id, round: "wildcard").relation

      expect(results).to contain_exactly(wildcard)
    end
  end

  describe "filter by week" do
    it "returns only games in the given week" do
      season = create_nfl_season
      build_game(season, 0, 1, week: 1)
      week_two = build_game(season, 2, 3, week: 2)

      results = described_class.new(season_id: season.id, week: "2").relation

      expect(results).to contain_exactly(week_two)
    end

    it "ignores non-numeric weeks" do
      season = create_nfl_season
      build_game(season, 0, 1, week: 1)

      results = described_class.new(season_id: season.id, week: "abc").relation

      expect(results.size).to eq(1)
    end
  end

  describe "filter by team" do
    it "matches games where the team plays at home or away" do
      season = create_nfl_season
      home_game = build_game(season, 1, 2)
      away_game = build_game(season, 3, 1)
      build_game(season, 2, 3)
      team_id = season.season_teams.order(:id).second.team_id

      results = described_class.new(season_id: season.id, team_id: team_id).relation

      expect(results).to contain_exactly(home_game, away_game)
    end

    it "returns no games for a team not in the season" do
      season = create_nfl_season
      build_game(season, 0, 1)

      results = described_class.new(season_id: season.id, team_id: 999_999).relation

      expect(results).to be_empty
    end
  end

  describe "filter by date range" do
    it "returns games on or after the from date" do
      season = create_nfl_season
      build_game(season, 0, 1, starts_at: Time.zone.local(2030, 1, 5, 13))
      late = build_game(season, 2, 3, starts_at: Time.zone.local(2030, 2, 5, 13))

      results = described_class.new(season_id: season.id, from: "2030-02-01").relation

      expect(results).to contain_exactly(late)
    end

    it "returns games on or before the to date, inclusive of that day" do
      season = create_nfl_season
      early = build_game(season, 0, 1, starts_at: Time.zone.local(2030, 1, 5, 23, 30))
      build_game(season, 2, 3, starts_at: Time.zone.local(2030, 2, 5, 13))

      results = described_class.new(season_id: season.id, to: "2030-01-05").relation

      expect(results).to contain_exactly(early)
    end

    it "combines from and to" do
      season = create_nfl_season
      build_game(season, 0, 1, starts_at: Time.zone.local(2030, 1, 5, 13))
      mid = build_game(season, 2, 3, starts_at: Time.zone.local(2030, 2, 5, 13))
      build_game(season, 0, 2, starts_at: Time.zone.local(2030, 3, 5, 13))

      results = described_class.new(season_id: season.id, from: "2030-02-01", to: "2030-02-28").relation

      expect(results).to contain_exactly(mid)
    end

    it "ignores malformed dates" do
      season = create_nfl_season
      build_game(season, 0, 1)

      results = described_class.new(season_id: season.id, from: "not-a-date", to: "13/13/13").relation

      expect(results.size).to eq(1)
    end
  end

  describe "sort" do
    it "sorts by starts_at asc by default" do
      season = create_nfl_season
      late = build_game(season, 0, 1, starts_at: Time.zone.local(2030, 2, 5, 13))
      early = build_game(season, 2, 3, starts_at: Time.zone.local(2030, 1, 5, 13))

      results = described_class.new(season_id: season.id).relation.to_a

      expect(results).to eq([early, late])
    end

    it "sorts by week desc when requested" do
      season = create_nfl_season
      week_one = build_game(season, 0, 1, week: 1)
      week_two = build_game(season, 2, 3, week: 2)

      results = described_class.new(season_id: season.id, sort: "week", dir: "desc").relation.to_a

      expect(results).to eq([week_two, week_one])
    end

    it "puts nil weeks last regardless of direction" do
      season = create_nfl_season
      numbered = build_game(season, 0, 1, week: 2)
      blank = build_game(season, 2, 3, week: nil)

      asc = described_class.new(season_id: season.id, sort: "week", dir: "asc").relation.to_a
      desc = described_class.new(season_id: season.id, sort: "week", dir: "desc").relation.to_a

      expect(asc).to eq([numbered, blank])
      expect(desc).to eq([numbered, blank])
    end

    it "falls back to defaults on unknown sort/dir" do
      query = described_class.new(sort: "bogus", dir: "sideways")

      expect(query.sort_column).to eq("starts_at")
      expect(query.sort_dir).to eq("asc")
    end
  end

  describe "#to_url_params" do
    it "merges overrides and compact_blanks empty filters" do
      season = create_nfl_season
      query = described_class.new(
        season_id: season.id, status: "final", week: "3", from: "2030-01-01"
      )

      url_params = query.to_url_params(sort: "week", dir: "desc")

      expect(url_params).to eq(
        season_id: season.id, status: "final", week: 3,
        from: "2030-01-01", sort: "week", dir: "desc"
      )
    end
  end
end
