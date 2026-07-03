# frozen_string_literal: true

require "rails_helper"

RSpec.describe Seasons::Selectable do
  describe ".call" do
    it "offers active seasons plus only the earliest upcoming season per sport" do
      sport = create(:sport)
      active = create(:season, sport: sport, year: 2025, status: "active")
      soonest_upcoming = create(:season, sport: sport, year: 2026, status: "upcoming")
      later_upcoming = create(:season, sport: sport, year: 2027, status: "upcoming")
      completed = create(:season, sport: sport, year: 2024, status: "completed")

      seasons = Seasons::Selectable.call

      expect(seasons).to include(active, soonest_upcoming)
      expect(seasons).not_to include(later_upcoming, completed)
    end

    it "orders upcoming seasons (soonest first) ahead of active ones (most recently started first)" do
      football = create(:sport, key: "nfl", name: "Football")
      basketball = create(:sport, key: "nba", name: "Basketball")
      baseball = create(:sport, key: "mlb", name: "Baseball")
      older_active = create(:season, sport: football, year: 2024, status: "active",
        starts_on: Date.new(2024, 9, 1), ends_on: Date.new(2025, 2, 28))
      newer_active = create(:season, sport: basketball, year: 2025, status: "active",
        starts_on: Date.new(2025, 4, 1), ends_on: Date.new(2025, 11, 30))
      upcoming_soon = create(:season, sport: baseball, year: 2026, status: "upcoming",
        starts_on: Date.new(2026, 4, 1), ends_on: Date.new(2026, 11, 30))
      upcoming_later = create(:season, sport: football, year: 2026, status: "upcoming",
        starts_on: Date.new(2026, 9, 1), ends_on: Date.new(2027, 2, 28))

      expect(Seasons::Selectable.call.to_a).to eq(
        [upcoming_soon, upcoming_later, newer_active, older_active]
      )
    end
  end

  describe ".default" do
    it "prefers the soonest upcoming season" do
      sport = create(:sport)
      create(:season, sport: sport, year: 2025, status: "active")
      upcoming = create(:season, sport: sport, year: 2026, status: "upcoming")

      expect(Seasons::Selectable.default).to eq(upcoming)
    end

    it "falls back to the most recently started active season when nothing is upcoming" do
      football = create(:sport, key: "nfl", name: "Football")
      basketball = create(:sport, key: "nba", name: "Basketball")
      create(:season, sport: football, year: 2024, status: "active",
        starts_on: Date.new(2024, 9, 1), ends_on: Date.new(2025, 2, 28))
      newer_active = create(:season, sport: basketball, year: 2025, status: "active",
        starts_on: Date.new(2025, 4, 1), ends_on: Date.new(2025, 11, 30))

      expect(Seasons::Selectable.default).to eq(newer_active)
    end

    it "returns nil when no seasons are selectable" do
      expect(Seasons::Selectable.default).to be_nil
    end
  end
end
