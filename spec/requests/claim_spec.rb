# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Claiming a seat", type: :request do
  it "claims an open seat and stamps joined_at" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    second_seat = league.participants.find_by(draft_position: 2)

    expect { claim_seat_via_http(league, second_seat) }
      .to change { second_seat.reload.joined_at }.from(nil)
    expect(response).to redirect_to(league_path(league))
  end

  it "refuses to claim a taken seat" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    second_seat = league.participants.find_by(draft_position: 2)
    second_seat.update!(joined_at: Time.current)

    claim_seat_via_http(league, second_seat)

    expect(response).to redirect_to(league_path(league))
    follow_redirect!
    expect(response.body).to include("already claimed")
  end
end
