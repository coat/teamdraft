# frozen_string_literal: true

require "rails_helper"

RSpec.describe League do
  describe "validations" do
    it "rejects size < 2 at the model layer" do
      season = create(:season)

      league = League.new(name: "x", season: season, size: 1, slug: "abc")

      expect(league).not_to be_valid
      expect(league.errors[:size]).to be_present
    end

    it "rejects size < 2 at the DB layer" do
      season = create(:season)
      league = League.new(name: "x", season: season, size: 1, slug: "abc-#{SecureRandom.hex(3)}")

      expect { league.save(validate: false) }
        .to raise_error(ActiveRecord::StatementInvalid, /leagues_size_range/)
    end

    it "rejects an invalid status at the DB layer" do
      season = create(:season)
      league = League.new(name: "x", season: season, size: 2, status: "garbage", slug: "abc-#{SecureRandom.hex(3)}")

      expect { league.save(validate: false) }
        .to raise_error(ActiveRecord::StatementInvalid, /leagues_status_valid/)
    end
  end

  describe "#picks_per_participant" do
    it "splits season teams across participants" do
      season = create_nfl_season(team_count: 32)

      league = League.new(season: season, size: 2)

      expect(league.picks_per_participant).to eq(16)
    end
  end
end
