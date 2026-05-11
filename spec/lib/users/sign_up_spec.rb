# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::SignUp do
  it "creates the user with default values" do
    user = Users::SignUp.call(
      email_address: "alice@example.com",
      password: "supersecret",
      password_confirmation: "supersecret"
    )

    expect(user).to be_persisted
    expect(user.email_address).to eq("alice@example.com")
    expect(user.admin).to be(false)
  end

  it "links any participants whose claim_token is in the cookie" do
    league = create(:league, season: create_nfl_season(team_count: 2))
    owner = create(:participant, :owner, league: league)

    user = Users::SignUp.call(
      email_address: "alice@example.com",
      password: "supersecret",
      password_confirmation: "supersecret",
      claim_tokens: [owner.claim_token]
    )

    expect(owner.reload.user_id).to eq(user.id)
  end

  it "rejects mismatched password confirmation" do
    expect {
      Users::SignUp.call(
        email_address: "alice@example.com",
        password: "supersecret",
        password_confirmation: "different"
      )
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects too-short passwords" do
    expect {
      Users::SignUp.call(
        email_address: "alice@example.com",
        password: "short",
        password_confirmation: "short"
      )
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
