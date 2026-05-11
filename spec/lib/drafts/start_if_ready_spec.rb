# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::StartIfReady do
  it "transitions to drafting and schedules the first clock when both seats are joined (live)" do
    league = create_ready_league(draft_mode: "live", pick_clock_seconds: 30)

    expect { Drafts::StartIfReady.call(league: league) }
      .to change { league.reload.status }.from("draft_pending").to("drafting")
      .and have_enqueued_job(Drafts::PickClockJob).with(league.id, 1)
  end

  it "transitions to drafting but does not schedule a clock in manual mode" do
    league = create_ready_league(draft_mode: "manual", pick_clock_seconds: nil)

    Drafts::StartIfReady.call(league: league)

    expect(league.reload.status).to eq("drafting")
    expect(enqueued_jobs.map { |j| j[:job] }).not_to include(Drafts::PickClockJob)
  end

  it "does nothing when a seat is unclaimed" do
    season = create_nfl_season(team_count: 4)
    league = create(:league, season: season)
    create(:participant, :owner, league: league)
    create(:participant, :unjoined, league: league, draft_position: 2)

    expect { Drafts::StartIfReady.call(league: league) }
      .not_to change { league.reload.status }
  end

  it "schedules a StartDraftJob when draft_scheduled_at is in the future" do
    league = create_ready_league(
      draft_mode: "live", pick_clock_seconds: 30,
      draft_scheduled_at: 1.hour.from_now
    )

    expect { Drafts::StartIfReady.call(league: league) }
      .to have_enqueued_job(Drafts::StartDraftJob).with(league.id)

    expect(league.reload.status).to eq("draft_pending")
    expect(enqueued_jobs.map { |j| j[:job] }).not_to include(Drafts::PickClockJob)
  end

  it "starts immediately when draft_scheduled_at is in the past" do
    league = create_ready_league(
      draft_mode: "live", pick_clock_seconds: 30,
      draft_scheduled_at: 1.hour.ago
    )

    Drafts::StartIfReady.call(league: league)

    expect(league.reload.status).to eq("drafting")
  end

  def create_ready_league(**league_attrs)
    season = create_nfl_season(team_count: 4)
    create(:league, :with_two_participants, season: season, **league_attrs)
  end
end
