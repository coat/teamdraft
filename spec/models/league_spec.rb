# frozen_string_literal: true

require "rails_helper"

RSpec.describe League do
  it "has many league_seasons and durable identity (name + slug)" do
    league = League.create!(name: "Touchdown Tuesday")
    season_a = create(:season)
    season_b = create(:season, sport: season_a.sport, year: season_a.year + 1)
    create(:league_season, league: league, season: season_a, status: "completed")
    create(:league_season, league: league, season: season_b, status: "draft_pending")
    original_slug = league.slug

    expect(league.league_seasons.count).to eq(2)
    expect(league.reload.slug).to eq(original_slug)
    expect(original_slug).to match(/\Atouchdown-tuesday-\d{4}\z/)
  end

  describe "#current_league_season" do
    it "prefers the LeagueSeason whose Season is active" do
      league = League.create!(name: "X")
      sport = create(:sport, :nfl)
      old_season = create(:season, sport: sport, year: 2024, status: "completed")
      active_season = create(:season, sport: sport, year: 2025, status: "active")
      old_ls = create(:league_season, league: league, season: old_season)
      active_ls = create(:league_season, league: league, season: active_season)

      expect(league.current_league_season).to eq(active_ls)
      expect(old_ls).not_to eq(active_ls) # sanity
    end

    it "falls back to the most-recent LeagueSeason when no active one exists" do
      league = League.create!(name: "X")
      sport = create(:sport, :nfl)
      s1 = create(:season, sport: sport, year: 2023, status: "completed")
      s2 = create(:season, sport: sport, year: 2024, status: "completed")
      create(:league_season, league: league, season: s1)
      ls2 = create(:league_season, league: league, season: s2)

      expect(league.current_league_season).to eq(ls2)
    end
  end

  describe "#destroy" do
    it "cascades through league_seasons even when participants own draft_picks" do
      season = create_nfl_season(team_count: 2)
      league = League.create!(name: "Cascade Test")
      ls = create(:league_season, league: league, season: season)
      alice = create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
      bob = create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
      alice_team, bob_team = season.season_teams.first(2)
      DraftPick.create!(league_season: ls, participant: alice, season_team: alice_team, pick_number: 1)
      DraftPick.create!(league_season: ls, participant: bob, season_team: bob_team, pick_number: 2)

      league.destroy!

      expect(League.where(id: league.id)).to be_empty
      expect(LeagueSeason.where(id: ls.id)).to be_empty
      expect(Participant.where(league_season_id: ls.id)).to be_empty
      expect(DraftPick.where(league_season_id: ls.id)).to be_empty
    end
  end

  describe "slug generation" do
    it "derives the slug from the name with a random suffix" do
      league = League.create!(name: "Al vs Doug")
      expect(league.slug).to match(/\Aal-vs-doug-\d{4}\z/)
    end

    it "regenerates the slug when the name changes and keeps history" do
      league = League.create!(name: "Al vs Doug")
      old_slug = league.slug

      league.update!(name: "Al vs Douglas")

      expect(league.slug).to match(/\Aal-vs-douglas-\d{4}\z/)
      expect(league.slug).not_to eq(old_slug)
      expect(League.friendly.find(old_slug)).to eq(league)
    end

    it "tolerates colliding names by appending a different suffix" do
      League.create!(name: "Rivals")
      other = League.create!(name: "Rivals")
      expect(other.slug).to match(/\Arivals-\d{4}\z/)
      expect(other.slug).not_to eq(League.first.slug)
    end
  end
end
