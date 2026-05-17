# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leagues index (home)", type: :request do
  context "visitor with no leagues" do
    it "renders the landing page with the quick-start form" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Start a draft")
      expect(response.body).to include("league[your_name]")
    end
  end

  context "visitor with one league via cookie" do
    it "redirects to that league" do
      create_nfl_season(team_count: 4)
      league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")

      get root_path

      expect(response).to redirect_to(league_path(league))
    end
  end

  context "visitor with multiple leagues" do
    it "renders an index with each league" do
      create_nfl_season(team_count: 4)
      league1 = create_league_via_http(your_name: "Alice", opponent_name: "Bob")
      league2 = create_league_via_http(your_name: "Alice", opponent_name: "Carol")

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(league1.name)
      expect(response.body).to include(league2.name)
    end
  end
end
