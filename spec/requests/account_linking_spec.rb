# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Account linking on league actions", type: :request do
  it "links the owner participant to current_user when a signed-in user creates a league" do
    create_nfl_season(team_count: 4)
    user = sign_in_new_user("alice@example.com")

    create_league_via_http(your_name: "Alice", opponent_name: "Bob")

    league = user.participants.first.league
    expect(user.participants.joins(:league_season).find_by(league_seasons: {league_id: league.id}, is_owner: true)).to be_present
  end

  it "links a participant to current_user when a signed-in user claims an open seat" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    bob_seat = league.participants.find_by(draft_position: 2)
    user = sign_in_new_user("bob@example.com")

    claim_seat_via_http(league, bob_seat)

    expect(bob_seat.reload.user_id).to eq(user.id)
  end

  it "hides the create-account upsell on the league page when signed in" do
    create_nfl_season(team_count: 4)
    user = sign_in_new_user("alice@example.com")
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")

    get league_path(league)

    expect(response.body).not_to include("Save your seat across devices")
    expect(user.participants.joins(:league_season).find_by(league_seasons: {league_id: league.id}, is_owner: true)).to be_present
  end

  def sign_in_new_user(email)
    post registration_path, params: {
      user: {email_address: email, password: "supersecret", password_confirmation: "supersecret"}
    }
    User.find_by!(email_address: email)
  end
end
