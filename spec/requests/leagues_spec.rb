# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leagues", type: :request do
  describe "GET /" do
    it "renders the landing page" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Start a draft")
    end
  end

  describe "POST /leagues" do
    it "creates a league and redirects to the slug URL" do
      create_nfl_season(team_count: 4)

      expect {
        post "/leagues", params: {league: {your_name: "Alice", opponent_name: "Bob"}}
      }.to change(League, :count).by(1)

      league = League.last
      expect(league.name).to eq("Alice vs Bob")
      expect(league.participants.count).to eq(2)
      expect(league.owner.display_name).to eq("Alice")
      expect(response).to redirect_to(league_path(league))
    end

    it "rejects blank names" do
      create_nfl_season(team_count: 4)

      post "/leagues", params: {league: {your_name: "", opponent_name: ""}}

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /leagues/:slug" do
    it "shows the league page" do
      season = create_nfl_season(team_count: 4)
      league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first

      get league_path(league)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice vs Bob")
    end

    it "offers an invite-code prompt for visitors with no cookie" do
      season = create_nfl_season(team_count: 4)
      league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first

      get league_path(league)

      expect(response.body).to include("Have an invite code?")
      expect(response.body).not_to include("Are you Bob?")
    end

    it "auto-claims the lone open seat after the visitor enters a valid invite code" do
      season = create_nfl_season(team_count: 4)
      league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
      code = league.current_league_season.invite_code
      bob_seat = league.participants.find_by(draft_position: 2)

      post verify_invite_league_path(league), params: {code: code}
      follow_redirect!
      # Claiming completes the seat roster, which starts the draft and
      # bounces claimed viewers to /draft. The welcome flash survives the
      # extra hop; we just need to follow it.
      follow_redirect! if response.redirect?

      expect(bob_seat.reload.joined_at).to be_present
      expect(flash[:notice].to_s + response.body).to include("Welcome, Bob")
      expect(response.body).not_to include("Are you Bob?")
    end
  end
end
