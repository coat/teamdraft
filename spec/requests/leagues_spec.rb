# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Leagues", type: :request do
  describe "GET /" do
    it "renders the landing page" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Start a draft")
    end

    describe "season selection" do
      # Helper that sets ends_on automatically so the Season validation passes.
      def make_season(sport:, status:, starts_on:, label:, year:)
        create(:season, sport: sport, status: status,
          starts_on: starts_on, ends_on: starts_on + 6.months,
          label: label, year: year)
      end

      it "groups seasons into Upcoming and In Progress optgroups" do
        nfl = create(:sport, :nfl)
        make_season(sport: nfl, status: "upcoming", starts_on: 6.months.from_now.to_date, label: "Upcoming NFL", year: 2026)
        make_season(sport: nfl, status: "active", starts_on: 6.months.ago.to_date, label: "Active NFL", year: 2025)

        get "/"

        expect(response.body).to include(%(optgroup label="Upcoming"))
        expect(response.body).to include(%(optgroup label="In Progress"))
      end

      it "places upcoming seasons before active seasons" do
        nfl = create(:sport, :nfl)
        make_season(sport: nfl, status: "upcoming", starts_on: 6.months.from_now.to_date, label: "Upcoming NFL", year: 2026)
        make_season(sport: nfl, status: "active", starts_on: 6.months.ago.to_date, label: "Active NFL", year: 2025)

        get "/"

        expect(response.body).to match(/Upcoming.*In Progress/m)
      end

      it "sorts upcoming seasons across sports by starts_on ascending" do
        nfl = create(:sport, :nfl)
        nba = create(:sport, :nba)
        # NFL starts later than NBA → NBA should appear first
        make_season(sport: nfl, status: "upcoming", starts_on: Date.new(2026, 9, 15), label: "2026 NFL", year: 2026)
        make_season(sport: nba, status: "upcoming", starts_on: Date.new(2026, 8, 1), label: "2026 NBA", year: 2026)

        get "/"

        expect(response.body).to match(/2026 NBA.*2026 NFL/m)
      end

      it "sorts active seasons across sports by starts_on descending" do
        nfl = create(:sport, :nfl)
        nba = create(:sport, :nba)
        # NBA started more recently → NBA should appear first
        make_season(sport: nfl, status: "active", starts_on: Date.new(2025, 9, 1), label: "2025 NFL", year: 2025)
        make_season(sport: nba, status: "active", starts_on: Date.new(2026, 1, 1), label: "2026 NBA", year: 2026)

        get "/"

        expect(response.body).to match(/2026 NBA.*2025 NFL/m)
      end

      it "only shows the earliest upcoming season per sport" do
        nfl = create(:sport, :nfl)
        make_season(sport: nfl, status: "upcoming", starts_on: Date.new(2026, 9, 1), label: "2026 NFL", year: 2026)
        make_season(sport: nfl, status: "upcoming", starts_on: Date.new(2027, 9, 1), label: "2027 NFL", year: 2027)

        get "/"

        expect(response.body).to include("2026 NFL")
        expect(response.body).not_to include("2027 NFL")
      end

      it "shows all active seasons regardless of how many per sport" do
        nfl = create(:sport, :nfl)
        make_season(sport: nfl, status: "active", starts_on: Date.new(2024, 9, 1), label: "2024 NFL", year: 2024)
        make_season(sport: nfl, status: "active", starts_on: Date.new(2025, 9, 1), label: "2025 NFL", year: 2025)

        get "/"

        expect(response.body).to include("2024 NFL")
        expect(response.body).to include("2025 NFL")
      end

      it "preselects the soonest upcoming season when available" do
        nfl = create(:sport, :nfl)
        upcoming = make_season(sport: nfl, status: "upcoming", starts_on: Date.new(2026, 9, 1), label: "2026 NFL", year: 2026)
        make_season(sport: nfl, status: "active", starts_on: Date.new(2025, 9, 1), label: "2025 NFL", year: 2025)

        get "/"

        expect(response.body).to include(%(selected="selected" value="#{upcoming.id}"))
      end

      it "falls back to active when no upcoming season exists" do
        nfl = create(:sport, :nfl)
        make_season(sport: nfl, status: "active", starts_on: Date.new(2025, 9, 1), label: "2025 NFL", year: 2025)
        make_season(sport: nfl, status: "active", starts_on: Date.new(2024, 11, 1), label: "2024 NFL", year: 2024)

        get "/"

        # Most-recently-started active should be selected
        expect(response.body).to match(/selected.*2025 NFL/)
      end
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

      expect(response).to have_http_status(:unprocessable_content)
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
