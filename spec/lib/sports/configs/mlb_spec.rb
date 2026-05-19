# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sports::Configs::Mlb do
  it "builds a config with 30 teams and a five-round playoff scoring ladder" do
    config = Sports::Configs::Mlb.build

    expect(config.key).to eq("mlb")
    expect(config.name).to eq("MLB")
    expect(config.teams.size).to eq(30)
    expect(config.teams.map { |t| t[:abbreviation] }.uniq.size).to eq(30)
    expect(config.teams.map { |t| t[:external_id] }.uniq.size).to eq(30)

    round_keys = config.scoring_rules.filter_map { |r| r[:round_key] }
    expect(round_keys).to eq(%w[wildcard division_series lcs world_series])

    kinds = config.scoring_rules.map { |r| r[:kind] }
    expect(kinds).to contain_exactly("regular_win", "playoff_appearance", "playoff_appearance", "playoff_appearance", "playoff_appearance", "championship_win")
  end

  it "installs cleanly via Sports::Installer" do
    Sports::Installer.call(key: "mlb", config: Sports::Configs::Mlb.build)

    sport = Sport.find_by(key: "mlb")
    expect(sport).to be_present
    expect(sport.teams.count).to eq(30)
    expect(sport.scoring_rules.where(kind: "playoff_appearance").pluck(:round_key))
      .to eq(%w[wildcard division_series lcs world_series])
  end
end
