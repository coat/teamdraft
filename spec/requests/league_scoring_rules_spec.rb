# frozen_string_literal: true

require "rails_helper"

RSpec.describe "League scoring rules", type: :request do
  it "lets the cookie owner reach the scoring editor" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")

    get edit_league_scoring_rules_path(league)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Scoring")
    expect(response.body).to include("Regular-season win")
  end

  it "lets the owner update point values" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    ls = league.current_league_season
    rule = league.current_league_season.season.sport.scoring_rules.find_by(event_type: "regular_win")
    override = ls.scoring_rule_overrides.find_by(scoring_rule: rule)

    patch league_scoring_rules_path(league), params: {
      overrides: {override.id.to_s => {points: "3"}}
    }

    expect(response).to redirect_to(edit_league_scoring_rules_path(league))
    expect(override.reload.points).to eq(3)
  end

  it "resets all overrides back to sport defaults" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    ls = league.current_league_season
    rule = ls.season.sport.scoring_rules.find_by(event_type: "regular_win")
    ls.scoring_rule_overrides.find_by(scoring_rule: rule).update!(points: 99)

    post reset_league_scoring_rules_path(league)

    expect(response).to redirect_to(edit_league_scoring_rules_path(league))
    expect(ls.scoring_rule_overrides.find_by(scoring_rule: rule).reload.points).to eq(rule.points)
  end

  it "blocks non-owners" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)

    get edit_league_scoring_rules_path(league)

    expect(response).to redirect_to(league_path(league))
  end

  it "rejects negative points and re-renders" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    ls = league.current_league_season
    rule = ls.season.sport.scoring_rules.find_by(event_type: "regular_win")
    override = ls.scoring_rule_overrides.find_by(scoring_rule: rule)
    original_points = override.points

    patch league_scoring_rules_path(league), params: {
      overrides: {override.id.to_s => {points: "-2"}}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(override.reload.points).to eq(original_points)
  end
end
