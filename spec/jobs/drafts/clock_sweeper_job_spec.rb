# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::ClockSweeperJob do
  it "re-enqueues PickClockJob when the deadline plus grace has passed" do
    ls = drafting_ls
    ls.update!(draft_started_at: (ls.pick_clock_seconds + Drafts::ClockSweeperJob::GRACE_SECONDS + 1).seconds.ago)

    expect { Drafts::ClockSweeperJob.perform_now }
      .to have_enqueued_job(Drafts::PickClockJob).with(ls.id, ls.current_pick_number)
  end

  it "uses the last pick's picked_at as the deadline base when picks exist" do
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season)
    start_drafting!(ls)
    Drafts::SubmitPick.call(league_season: ls, season_team: ls.season.season_teams.first)
    ls.reload
    last_pick = ls.draft_picks.last
    last_pick.update_columns(picked_at: (ls.pick_clock_seconds + Drafts::ClockSweeperJob::GRACE_SECONDS + 1).seconds.ago)

    expect { Drafts::ClockSweeperJob.perform_now }
      .to have_enqueued_job(Drafts::PickClockJob).with(ls.id, ls.current_pick_number)
  end

  it "does not enqueue when the deadline has not yet passed" do
    ls = drafting_ls
    ls.update!(draft_started_at: 1.second.ago)

    expect { Drafts::ClockSweeperJob.perform_now }
      .not_to have_enqueued_job(Drafts::PickClockJob)
  end

  it "skips league seasons not in drafting status" do
    ls = drafting_ls
    ls.update!(status: "in_season", draft_started_at: 1.hour.ago)

    expect { Drafts::ClockSweeperJob.perform_now }
      .not_to have_enqueued_job(Drafts::PickClockJob)
  end

  it "skips manual draft mode league seasons" do
    ls = drafting_ls
    ls.update!(draft_mode: "manual", draft_started_at: 1.hour.ago)

    expect { Drafts::ClockSweeperJob.perform_now }
      .not_to have_enqueued_job(Drafts::PickClockJob)
  end

  it "skips league seasons with no pick clock" do
    ls = drafting_ls
    ls.update_columns(pick_clock_seconds: nil, draft_started_at: 1.hour.ago)

    expect { Drafts::ClockSweeperJob.perform_now }
      .not_to have_enqueued_job(Drafts::PickClockJob)
  end

  def drafting_ls
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season)
    start_drafting!(ls)
  end
end
