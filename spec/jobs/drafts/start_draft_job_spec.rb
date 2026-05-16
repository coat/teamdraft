# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::StartDraftJob do
  it "transitions a ready league season into drafting" do
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season, draft_scheduled_at: 1.minute.ago)

    Drafts::StartDraftJob.perform_now(ls.id)

    expect(ls.reload.status).to eq("drafting")
  end

  it "is a no-op when seats are still open" do
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, season: season)
    create(:participant, :owner, league_season: ls)
    create(:participant, :unjoined, league_season: ls, draft_position: 2)

    Drafts::StartDraftJob.perform_now(ls.id)

    expect(ls.reload.status).to eq("draft_pending")
  end
end
