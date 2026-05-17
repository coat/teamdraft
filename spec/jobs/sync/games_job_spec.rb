# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sync::GamesJob do
  it "imports games and queues a recompute when finals are present" do
    season = create_nfl_season(team_count: 2)
    home, away = season.teams.first(2)
    home.update!(external_id: "T1")
    away.update!(external_id: "T2")

    SportsData::TheSportsDbProvider.round_numbers_for("nfl").each do |round|
      events = (round == "1") ? [
        {"idEvent" => "G-1", "idHomeTeam" => "T1", "idAwayTeam" => "T2",
         "intHomeScore" => "24", "intAwayScore" => "10",
         "dateEvent" => "2025-09-07", "strTime" => "17:00:00",
         "intRound" => "1", "strStatus" => "Match Finished"}
      ] : []
      stub_request(:get, "https://www.thesportsdb.com/api/v1/json/123/eventsround.php?id=4391&r=#{round}&s=#{season.year}")
        .to_return(
          status: 200,
          body: {"events" => events}.to_json,
          headers: {"Content-Type" => "application/json"}
        )
    end

    expect { Sync::GamesJob.perform_now(season.id) }
      .to change(Game, :count).by(1)
      .and have_enqueued_job(Scoring::RecomputeJob).with(season.id)
  end
end
