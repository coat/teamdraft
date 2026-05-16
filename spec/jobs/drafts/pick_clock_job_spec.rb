# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::PickClockJob do
  it "auto-picks when the expected pick number is still current" do
    ls = create_drafting_ls

    expect { Drafts::PickClockJob.perform_now(ls.id, ls.current_pick_number) }
      .to change(DraftPick, :count).by(1)
  end

  it "is a no-op when the human picked first" do
    ls = create_drafting_ls
    Drafts::SubmitPick.call(league_season: ls, season_team: ls.season.season_teams.first)

    expect { Drafts::PickClockJob.perform_now(ls.id, 1) }
      .not_to change(DraftPick, :count)
  end

  it "is a no-op for manual league seasons" do
    ls = create_drafting_ls
    ls.update!(draft_mode: "manual")

    expect { Drafts::PickClockJob.perform_now(ls.id, ls.current_pick_number) }
      .not_to change(DraftPick, :count)
  end

  def create_drafting_ls
    season = create_nfl_season(team_count: 4)
    ls = create(:league_season, :with_two_participants, season: season)
    start_drafting!(ls)
  end
end
