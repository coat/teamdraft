# frozen_string_literal: true

require "rails_helper"

RSpec.describe Season do
  describe "#score_sync_reason" do
    it "returns :window when a game's starts_at is inside the pre/post window" do
      season = create_nfl_season(last_synced_at: 1.minute.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        starts_at: 10.minutes.from_now)

      expect(season.score_sync_reason).to eq(:window)
    end

    it "returns :window for a game that finished within the post-window tail" do
      season = create_nfl_season(last_synced_at: 1.minute.ago)
      home, away = season.season_teams.first(2)
      create(:game, :final, season: season, home_season_team: home, away_season_team: away,
        starts_at: 4.hours.ago)

      expect(season.score_sync_reason).to eq(:window)
    end

    it "returns :live when any game is in_progress, even outside the start window" do
      season = create_nfl_season(last_synced_at: 1.minute.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        status: "in_progress", starts_at: 12.hours.ago)

      expect(season.score_sync_reason).to eq(:live)
    end

    it "ignores an in_progress game older than the live lookback (unresolvable by the daily sync)" do
      season = create_nfl_season(last_synced_at: 1.minute.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        status: "in_progress", starts_at: 3.days.ago)

      expect(season.score_sync_reason).to be_nil
    end

    it "returns :fallback when no relevant games exist and last_synced_at is stale" do
      season = create_nfl_season(last_synced_at: 4.hours.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        starts_at: 3.days.from_now)

      expect(season.score_sync_reason).to eq(:fallback)
    end

    it "returns :fallback when last_synced_at is nil" do
      season = create_nfl_season(last_synced_at: nil)

      expect(season.score_sync_reason).to eq(:fallback)
    end

    it "returns nil when no relevant games exist and last_synced_at is recent" do
      season = create_nfl_season(last_synced_at: 10.minutes.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        starts_at: 3.days.from_now)

      expect(season.score_sync_reason).to be_nil
    end
  end

  describe "#round_for" do
    let(:season) do
      create(:season, sport: create(:sport, :mlb), year: 2026,
        starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5),
        round_windows: {
          "wildcard" => {"starts_on" => "2026-09-29", "ends_on" => "2026-10-02"},
          "world_series" => {"starts_on" => "2026-10-23", "ends_on" => "2026-11-04"}
        })
    end

    it "returns the round whose window covers the date, inclusive of boundaries" do
      expect(season.round_for(Date.new(2026, 9, 29))).to eq("wildcard")
      expect(season.round_for(Date.new(2026, 10, 2))).to eq("wildcard")
      expect(season.round_for(Date.new(2026, 10, 30))).to eq("world_series")
    end

    it "returns nil for dates outside every window, nil dates, and unconfigured seasons" do
      expect(season.round_for(Date.new(2026, 7, 4))).to be_nil
      expect(season.round_for(Date.new(2026, 10, 15))).to be_nil
      expect(season.round_for(nil)).to be_nil
      expect(create(:season).round_for(Date.new(2026, 7, 4))).to be_nil
    end
  end

  describe "round_windows validation" do
    # let, not create-per-call: sport keys are unique and some examples build
    # two seasons.
    let(:mlb) { create(:sport, :mlb) }

    def mlb_season(windows)
      build(:season, sport: mlb, year: 2026,
        starts_on: Date.new(2026, 3, 25), ends_on: Date.new(2026, 11, 5),
        round_windows: windows)
    end

    it "accepts valid non-overlapping windows within the season" do
      season = mlb_season(
        "wildcard" => {"starts_on" => "2026-09-29", "ends_on" => "2026-10-02"},
        "division_series" => {"starts_on" => "2026-10-03", "ends_on" => "2026-10-11"}
      )
      expect(season).to be_valid
    end

    it "rejects round keys the sport does not define" do
      season = mlb_season("divisional" => {"starts_on" => "2026-10-03", "ends_on" => "2026-10-11"})
      expect(season).not_to be_valid
      expect(season.errors[:round_windows].join).to include("divisional")
    end

    it "rejects windows missing a date or with reversed dates" do
      expect(mlb_season("wildcard" => {"starts_on" => "2026-09-29"})).not_to be_valid
      expect(mlb_season("wildcard" => {"starts_on" => "2026-10-02", "ends_on" => "2026-09-29"})).not_to be_valid
    end

    it "rejects windows outside the season and overlapping windows" do
      expect(mlb_season("wildcard" => {"starts_on" => "2026-11-06", "ends_on" => "2026-11-08"})).not_to be_valid
      overlapping = mlb_season(
        "wildcard" => {"starts_on" => "2026-09-29", "ends_on" => "2026-10-05"},
        "division_series" => {"starts_on" => "2026-10-03", "ends_on" => "2026-10-11"}
      )
      expect(overlapping).not_to be_valid
      expect(overlapping.errors[:round_windows].join).to include("overlap")
    end

    it "rejects a non-hash round_windows value" do
      season = mlb_season(["wildcard"])
      expect(season).not_to be_valid
      expect(season.errors[:round_windows].join).to include("map of round keys")
    end
  end
end
