# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::StartDraftJob do
  it "transitions a ready league into drafting" do
    season = create_nfl_season(team_count: 4)
    league = create(:league, :with_two_participants, season: season, draft_scheduled_at: 1.minute.ago)

    Drafts::StartDraftJob.perform_now(league.id)

    expect(league.reload.status).to eq("drafting")
  end

  it "is a no-op when seats are still open" do
    season = create_nfl_season(team_count: 4)
    league = create(:league, season: season)
    create(:participant, :owner, league: league)
    create(:participant, :unjoined, league: league, draft_position: 2)

    Drafts::StartDraftJob.perform_now(league.id)

    expect(league.reload.status).to eq("draft_pending")
  end
end
