# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leagues", type: :request do
  describe "GET /" do
    it "renders the landing page" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Draft a season with a friend")
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

    it "offers a claim prompt for visitors with no cookie" do
      season = create_nfl_season(team_count: 4)
      league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first

      get league_path(league)

      expect(response.body).to include("Are you Bob?")
    end
  end
end
