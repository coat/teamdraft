# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::PickClockJob do
  it "auto-picks when the expected pick number is still current" do
    league = create_drafting_league

    expect { Drafts::PickClockJob.perform_now(league.id, league.current_pick_number) }
      .to change(DraftPick, :count).by(1)
  end

  it "is a no-op when the human picked first" do
    league = create_drafting_league
    Drafts::SubmitPick.call(league: league, season_team: league.season.season_teams.first)

    expect { Drafts::PickClockJob.perform_now(league.id, 1) }
      .not_to change(DraftPick, :count)
  end

  it "is a no-op for manual leagues" do
    league = create_drafting_league
    league.update!(draft_mode: "manual")

    expect { Drafts::PickClockJob.perform_now(league.id, league.current_pick_number) }
      .not_to change(DraftPick, :count)
  end

  def create_drafting_league
    season = create_nfl_season(team_count: 4)
    league = create(:league, :with_two_participants, season: season)
    start_drafting!(league)
  end
end
