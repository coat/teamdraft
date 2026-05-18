# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scoring::Recompute do
  it "awards 1 point for a regular-season win" do
    season = create_nfl_season(team_count: 2)
    home, away = season.season_teams.first(2)
    game = create(:game, :final,
      season: season, home_season_team: home, away_season_team: away,
      home_score: 21, away_score: 14)

    Scoring::Recompute.call(season: season)

    events = ScoringEvent.where(game: game).to_a
    expect(events.size).to eq(1)
    expect(events.first.season_team).to eq(game.winner_season_team)
    expect(events.first.event_type).to eq("regular_win")
  end

  it "credits both wild-card participants with playoff_appearance" do
    season = create_nfl_season(team_count: 2)
    home, away = season.season_teams.first(2)
    game = create(:game, :final,
      season: season, round: "wildcard",
      home_season_team: home, away_season_team: away,
      home_score: 27, away_score: 24)

    Scoring::Recompute.call(season: season)

    events = ScoringEvent.where(game: game).order(:event_type).to_a
    expect(events.map(&:event_type)).to match_array(%w[playoff_appearance playoff_appearance])
  end

  it "credits bye teams with playoff_appearance via their divisional game" do
    season = create_nfl_season(team_count: 4)
    bye, opponent = season.season_teams.first(2)
    create(:game, :final,
      season: season, round: "divisional",
      home_season_team: bye, away_season_team: opponent,
      home_score: 31, away_score: 17)

    Scoring::Recompute.call(season: season)

    bye_events = ScoringEvent.where(season_team: bye).pluck(:event_type)
    expect(bye_events).to include("playoff_appearance", "divisional_appearance")
  end

  it "awards conference_appearance to championship-game participants and championship_win to the winner" do
    season = create_nfl_season(team_count: 2)
    home, away = season.season_teams.first(2)
    game = create(:game, :final,
      season: season, round: "championship",
      home_season_team: home, away_season_team: away,
      home_score: 31, away_score: 28)

    Scoring::Recompute.call(season: season)

    events = ScoringEvent.where(game: game).order(:event_type).to_a
    expect(events.map(&:event_type)).to match_array(
      %w[championship_appearance championship_appearance championship_win]
    )
    expect(events.find { |e| e.event_type == "championship_win" }.season_team).to eq(game.winner_season_team)
  end

  it "is idempotent across repeated calls" do
    season = create_nfl_season(team_count: 2)
    home, away = season.season_teams.first(2)
    create(:game, :final, season: season, home_season_team: home, away_season_team: away)
    Scoring::Recompute.call(season: season)

    expect { Scoring::Recompute.call(season: season) }.not_to change(ScoringEvent, :count)
  end

  it "ignores regular-season ties (no winner)" do
    season = create_nfl_season(team_count: 2)
    home, away = season.season_teams.first(2)
    create(:game, :final, season: season,
      home_season_team: home, away_season_team: away,
      home_score: 17, away_score: 17)

    expect { Scoring::Recompute.call(season: season) }.not_to change(ScoringEvent, :count)
  end
end
