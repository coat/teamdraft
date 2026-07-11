# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "GET /registration/new" do
    it "renders the sign-up form" do
      get new_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create your account")
    end
  end

  describe "POST /registration" do
    it "creates a user and signs them in" do
      expect {
        post registration_path, params: {
          user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
        }
      }.to change(User, :count).by(1).and change(Session, :count).by(1)
      expect(response).to redirect_to(root_url)
    end

    it "links any cookie-held participant claims to the new user" do
      create_nfl_season(team_count: 4)
      league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")

      post registration_path, params: {
        user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
      }

      user = User.find_by!(email_address: "alice@example.com")
      expect(league.owner.reload.user_id).to eq(user.id)
    end

    it "renders errors on invalid input" do
      post registration_path, params: {
        user: {email_address: "not-an-email", password: "x", password_confirmation: "y"}
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
