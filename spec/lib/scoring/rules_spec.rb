# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scoring::Rules do
  it ".for(sport) reads point values from sport scoring_rules" do
    sport = create(:sport, :nfl)
    rules = Scoring::Rules.for(sport)

    expect(rules.points_for("regular_win")).to eq(1)
    expect(rules.points_for("conference_appearance")).to eq(10)
  end

  it ".for_league_season(league_season) reads point values from per-league overrides" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season)
    rule = sport.scoring_rules.find_by(event_type: "regular_win")
    ls.scoring_rule_overrides.find_by(scoring_rule: rule).update!(points: 3)

    rules = Scoring::Rules.for_league_season(ls)

    expect(rules.points_for("regular_win")).to eq(3)
    expect(rules.points_for("conference_appearance")).to eq(10)
  end

  it "still resolves sport-level structural lookups (round_key, regular_win_event) for league_season rules" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season)

    rules = Scoring::Rules.for_league_season(ls)

    expect(rules.regular_win_event).to eq("regular_win")
    expect(rules.championship_win_event).to eq("championship_win")
    expect(rules.appearance_event_for_round("conference")).to eq("conference_appearance")
  end
end
