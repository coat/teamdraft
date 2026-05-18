# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeagueSeasonScoringRules::Seed do
  it "creates one override per sport scoring_rule, copying default points" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season, with_scoring_rule_overrides: false)

    LeagueSeasonScoringRules::Seed.call(ls)

    overrides = ls.scoring_rule_overrides.includes(:scoring_rule).to_a
    expect(overrides.size).to eq(sport.scoring_rules.count)
    overrides.each do |o|
      expect(o.points).to eq(o.scoring_rule.points)
    end
  end

  it "is idempotent — repeated calls do not duplicate or change overrides" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season)
    rule = sport.scoring_rules.find_by(event_type: "regular_win")
    ls.scoring_rule_overrides.find_by(scoring_rule: rule).update!(points: 99)

    expect { LeagueSeasonScoringRules::Seed.call(ls) }
      .not_to change(LeagueSeasonScoringRule, :count)

    expect(ls.scoring_rule_overrides.find_by(scoring_rule: rule).reload.points).to eq(99)
  end

  it "with reset: true, overwrites customized points back to sport defaults" do
    sport = create(:sport, :nfl)
    season = create(:season, sport: sport)
    ls = create(:league_season, season: season)
    rule = sport.scoring_rules.find_by(event_type: "regular_win")
    ls.scoring_rule_overrides.find_by(scoring_rule: rule).update!(points: 99)

    LeagueSeasonScoringRules::Seed.call(ls, reset: true)

    expect(ls.scoring_rule_overrides.find_by(scoring_rule: rule).reload.points).to eq(rule.points)
  end
end
