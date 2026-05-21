# frozen_string_literal: true

require "rails_helper"

RSpec.describe Seasons::LeagueLeaders do
  it "orders public leagues by their top participant's score, descending" do
    season = create_nfl_season(team_count: 4)
    big_team_one, big_team_two, small_team, _extra = season.season_teams.to_a
    ScoringEvent.create!(season_team: big_team_one, event_type: "regular_win", occurred_at: Time.current)
    ScoringEvent.create!(season_team: big_team_two, event_type: "regular_win", occurred_at: Time.current)
    ScoringEvent.create!(season_team: small_team, event_type: "regular_win", occurred_at: Time.current)

    big_league = create(:league_season, season: season, league: create(:league, name: "Big league"))
    big_owner = create(:participant, :owner, league_season: big_league, draft_position: 1)
    create(:participant, league_season: big_league, draft_position: 2)
    DraftPick.create!(league_season: big_league, participant: big_owner, season_team: big_team_one, pick_number: 1)
    DraftPick.create!(league_season: big_league, participant: big_owner, season_team: big_team_two, pick_number: 2)

    small_league = create(:league_season, season: season, league: create(:league, name: "Small league"))
    small_owner = create(:participant, :owner, league_season: small_league, draft_position: 1)
    create(:participant, league_season: small_league, draft_position: 2)
    DraftPick.create!(league_season: small_league, participant: small_owner, season_team: small_team, pick_number: 1)

    rows = Seasons::LeagueLeaders.call(season: season)

    expect(rows.map { |r| r.league_season.league.name }).to eq(["Big league", "Small league"])
    expect(rows.first.top_participant).to eq(big_owner)
    expect(rows.first.top_score).to be > rows.last.top_score
  end

  it "excludes private leagues" do
    season = create_nfl_season(team_count: 2)
    public_league = create(:league_season, season: season, league: create(:league, name: "Public"))
    create(:participant, :owner, league_season: public_league, draft_position: 1)
    create(:participant, league_season: public_league, draft_position: 2)

    hidden_league = create(:league_season, season: season, league: create(:league, name: "Hidden", private: true))
    create(:participant, :owner, league_season: hidden_league, draft_position: 1)

    rows = Seasons::LeagueLeaders.call(season: season)

    expect(rows.map { |r| r.league_season.league.name }).to eq(["Public"])
  end
end
