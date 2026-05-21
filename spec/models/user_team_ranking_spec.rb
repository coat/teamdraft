# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserTeamRanking do
  it "copies sport_id from the team on validation" do
    sport = create(:sport, :nfl)
    team = create(:team, sport: sport)
    user = create(:user)

    ranking = UserTeamRanking.new(user: user, team: team, rank: 1)
    ranking.valid?

    expect(ranking.sport_id).to eq(sport.id)
  end

  it "rejects a sport that does not match the team" do
    nfl = create(:sport, :nfl)
    nba = create(:sport, :nba)
    team = create(:team, sport: nfl)
    user = create(:user)

    ranking = UserTeamRanking.new(user: user, team: team, sport: nba, rank: 1)

    expect(ranking).to be_invalid
    expect(ranking.errors[:sport_id]).to be_present
  end

  it "requires rank to be positive" do
    user = create(:user)
    team = create(:team, sport: create(:sport, :nfl))

    ranking = UserTeamRanking.new(user: user, team: team, rank: 0)

    expect(ranking).to be_invalid
    expect(ranking.errors[:rank]).to be_present
  end

  it "forbids two rows with the same (user, team)" do
    user = create(:user)
    team = create(:team, sport: create(:sport, :nfl))
    create(:user_team_ranking, user: user, team: team, rank: 1)

    dup = UserTeamRanking.new(user: user, team: team, rank: 2)

    expect(dup).to be_invalid
    expect(dup.errors[:team_id]).to be_present
  end

  it "forbids two rows with the same (user, sport, rank)" do
    sport = create(:sport, :nfl)
    user = create(:user)
    team_a = create(:team, sport: sport)
    team_b = create(:team, sport: sport)
    create(:user_team_ranking, user: user, team: team_a, rank: 1)

    collision = UserTeamRanking.new(user: user, team: team_b, rank: 1)

    expect(collision).to be_invalid
    expect(collision.errors[:rank]).to be_present
  end
end
