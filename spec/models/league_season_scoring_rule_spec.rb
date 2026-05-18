# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeagueSeasonScoringRule do
  it "delegates label and event_type to the underlying scoring_rule" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season)
    rule = sport.scoring_rules.find_by(event_type: "regular_win")

    override = ls.scoring_rule_overrides.find_by(scoring_rule: rule)

    expect(override.event_type).to eq("regular_win")
    expect(override.label).to eq(rule.label)
    expect(override.kind).to eq("regular_win")
  end

  it "rejects negative point values" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season)
    rule = sport.scoring_rules.first

    override = ls.scoring_rule_overrides.find_by(scoring_rule: rule)
    override.points = -1

    expect(override).not_to be_valid
    expect(override.errors[:points]).to be_present
  end

  it "prevents two overrides of the same rule on the same league_season" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season)
    rule = sport.scoring_rules.first

    duplicate = ls.scoring_rule_overrides.build(scoring_rule: rule, points: 3)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:scoring_rule_id]).to be_present
  end
end
