# frozen_string_literal: true

require "rails_helper"

RSpec.describe Leagues::Create do
  it "defaults a live draft to LeagueSeason::DEFAULT_PICK_CLOCK_SECONDS when none is provided" do
    season = create_nfl_season(team_count: 4)

    league, = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season)

    expect(league.current_league_season.pick_clock_seconds).to eq(LeagueSeason::DEFAULT_PICK_CLOCK_SECONDS)
  end

  it "honors an explicit pick_clock_seconds value" do
    season = create_nfl_season(team_count: 4)

    league, = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob",
      season: season, pick_clock_seconds: 45)

    expect(league.current_league_season.pick_clock_seconds).to eq(45)
  end

  it "leaves manual drafts without a pick clock" do
    season = create_nfl_season(team_count: 4)

    league, = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob",
      season: season, draft_mode: "manual")

    expect(league.current_league_season.pick_clock_seconds).to be_nil
  end
end
