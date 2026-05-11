# frozen_string_literal: true

require "rails_helper"

RSpec.describe Game do
  it "rejects same home/away team at the DB layer" do
    season = create_nfl_season
    home = season.season_teams.first
    game = Game.new(
      season: season, round: "regular_season",
      home_season_team: home, away_season_team: home,
      kickoff_at: 1.day.from_now, status: "scheduled"
    )

    expect { game.save(validate: false) }
      .to raise_error(ActiveRecord::StatementInvalid, /games_distinct_teams/)
  end

  it "rejects final games without scores at the DB layer" do
    season = create_nfl_season
    home, away = season.season_teams.first(2)
    game = Game.new(
      season: season, round: "regular_season",
      home_season_team: home, away_season_team: away,
      kickoff_at: 1.day.ago, status: "final"
    )

    expect { game.save(validate: false) }
      .to raise_error(ActiveRecord::StatementInvalid, /games_final_has_scores/)
  end

  describe "#winner_season_team" do
    it "returns the home team when they outscored the away team" do
      season = create_nfl_season
      home, away = season.season_teams.first(2)

      game = create(:game, :final,
        season: season, home_season_team: home, away_season_team: away,
        home_score: 21, away_score: 14)

      expect(game.winner_season_team).to eq(home)
    end

    it "returns nil for ties" do
      season = create_nfl_season
      home, away = season.season_teams.first(2)

      game = create(:game, :final,
        season: season, home_season_team: home, away_season_team: away,
        home_score: 17, away_score: 17)

      expect(game.winner_season_team).to be_nil
    end
  end
end
