# frozen_string_literal: true

require "rails_helper"

RSpec.describe League do
  it "has many league_seasons and durable identity (name + slug)" do
    league = League.create!(name: "Touchdown Tuesday", slug: "touchdown-tuesday")
    season_a = create(:season)
    season_b = create(:season, sport: season_a.sport, year: season_a.year + 1)
    LeagueSeason.create!(league: league, season: season_a, status: "completed",
      size: 2, draft_mode: "manual", draft_order_style: "linear", current_pick_number: 1)
    LeagueSeason.create!(league: league, season: season_b, status: "draft_pending",
      size: 2, draft_mode: "manual", draft_order_style: "linear", current_pick_number: 1)

    expect(league.league_seasons.count).to eq(2)
    expect(league.reload.slug).to eq("touchdown-tuesday")
  end

  describe "#current_league_season" do
    it "prefers the LeagueSeason whose Season is active" do
      league = League.create!(name: "X", slug: "x")
      sport = create(:sport, :nfl)
      old_season = create(:season, sport: sport, year: 2024, status: "completed")
      active_season = create(:season, sport: sport, year: 2025, status: "active")
      old_ls = create(:league_season, league: league, season: old_season)
      active_ls = create(:league_season, league: league, season: active_season)

      expect(league.current_league_season).to eq(active_ls)
      expect(old_ls).not_to eq(active_ls) # sanity
    end

    it "falls back to the most-recent LeagueSeason when no active one exists" do
      league = League.create!(name: "X", slug: "x")
      sport = create(:sport, :nfl)
      s1 = create(:season, sport: sport, year: 2023, status: "completed")
      s2 = create(:season, sport: sport, year: 2024, status: "completed")
      create(:league_season, league: league, season: s1)
      ls2 = create(:league_season, league: league, season: s2)

      expect(league.current_league_season).to eq(ls2)
    end
  end
end
