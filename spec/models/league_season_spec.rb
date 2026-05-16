# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeagueSeason do
  it "rejects size < 2 at the model layer" do
    ls = build(:league_season, size: 1)

    expect(ls).not_to be_valid
    expect(ls.errors[:size]).to be_present
  end

  it "rejects size < 2 at the DB layer" do
    ls = build(:league_season, league: create(:league), season: create(:season), size: 1)

    expect { ls.save(validate: false) }
      .to raise_error(ActiveRecord::StatementInvalid, /league_seasons_size_range/)
  end

  it "rejects an invalid status at the DB layer" do
    ls = build(:league_season, league: create(:league), season: create(:season), status: "garbage")

    expect { ls.save(validate: false) }
      .to raise_error(ActiveRecord::StatementInvalid, /league_seasons_status_valid/)
  end

  it "enforces uniqueness of (league_id, season_id)" do
    ls = create(:league_season)
    dup = build(:league_season, league: ls.league, season: ls.season)

    expect(dup).not_to be_valid
    expect(dup.errors[:season_id]).to be_present
  end

  describe "#picks_per_participant" do
    it "splits season teams across participants" do
      season = create_nfl_season(team_count: 32)
      league = create(:league)
      ls = create(:league_season, league: league, season: season, size: 2)

      expect(ls.picks_per_participant).to eq(16)
    end
  end
end
