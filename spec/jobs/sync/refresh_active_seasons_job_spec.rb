# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sync::RefreshActiveSeasonsJob do
  include ActiveJob::TestHelper

  it "enqueues a GamesJob for each active season with [yesterday, today]" do
    sport = create(:sport, :nfl)
    active1 = create(:season, sport: sport, status: "active", external_id: "n-2026")
    active2 = create(:season, sport: create(:sport, :mlb), status: "active", external_id: "m-2026")
    create(:season, sport: sport, status: "completed", external_id: "n-2024")
    create(:season, sport: sport, status: "upcoming", external_id: "n-2027")

    Sync::RefreshActiveSeasonsJob.perform_now

    enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == Sync::GamesJob }
    expect(enqueued.map { |j| j[:args].first }).to contain_exactly(active1.id, active2.id)
    expect(enqueued).to all(satisfy { |j| j[:args].last["dates"] == [Date.yesterday.iso8601, Date.current.iso8601] })
  end

  it "skips active seasons that have no external_id" do
    sport = create(:sport, :nfl)
    create(:season, sport: sport, status: "active", external_id: nil)

    Sync::RefreshActiveSeasonsJob.perform_now

    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == Sync::GamesJob }).to be_empty
  end
end
