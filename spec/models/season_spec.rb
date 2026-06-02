# frozen_string_literal: true

require "rails_helper"

RSpec.describe Season do
  describe "#score_sync_reason" do
    it "returns :window when a game's kickoff_at is inside the pre/post window" do
      season = create_nfl_season(last_synced_at: 1.minute.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        kickoff_at: 10.minutes.from_now)

      expect(season.score_sync_reason).to eq(:window)
    end

    it "returns :window for a game that finished within the post-window tail" do
      season = create_nfl_season(last_synced_at: 1.minute.ago)
      home, away = season.season_teams.first(2)
      create(:game, :final, season: season, home_season_team: home, away_season_team: away,
        kickoff_at: 4.hours.ago)

      expect(season.score_sync_reason).to eq(:window)
    end

    it "returns :live when any game is in_progress, even outside the kickoff window" do
      season = create_nfl_season(last_synced_at: 1.minute.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        status: "in_progress", kickoff_at: 12.hours.ago)

      expect(season.score_sync_reason).to eq(:live)
    end

    it "returns :fallback when no relevant games exist and last_synced_at is stale" do
      season = create_nfl_season(last_synced_at: 4.hours.ago)
      home, away = season.season_teams.first(2)
      create(:game, season: season, home_season_team: home, away_season_team: away,
        kickoff_at: 3.days.from_now)

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
        kickoff_at: 3.days.from_now)

      expect(season.score_sync_reason).to be_nil
    end
  end
end
