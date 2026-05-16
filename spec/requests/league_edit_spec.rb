# frozen_string_literal: true

require "rails_helper"

RSpec.describe "League edit", type: :request do
  it "redirects cookie-only owners to a sign-up CTA" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob")

    get edit_league_path(league)

    expect(response).to redirect_to(league_path(league))
    follow_redirect!
    expect(response.body).to include("Sign in as the league owner")
  end

  it "lets the signed-in owner rename the league and regenerates the slug" do
    create_nfl_season(team_count: 4)
    create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    league = League.last
    old_slug = league.slug

    patch league_path(league), params: {league: {name: "Alice's Big Draft"}}

    expect(response).to redirect_to(league_path(league.reload))
    expect(league.name).to eq("Alice's Big Draft")
    expect(league.slug).to match(/\Aalice-s-big-draft-\d{4}\z/)
    expect(league.slug).not_to eq(old_slug)

    # Old slug still resolves via friendly_id history.
    get "/leagues/#{old_slug}"
    expect(response).to have_http_status(:moved_permanently)
    follow_redirect!
    expect(request.path).to eq(league_path(league))
  end

  it "toggles the private flag" do
    create_nfl_season(team_count: 4)
    create_league_via_http(your_name: "Alice", opponent_name: "Bob")
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    league = League.last

    patch league_path(league), params: {league: {private: "1"}}

    expect(response).to redirect_to(league_path(league.reload))
    expect(league.private?).to be(true)
  end

  it "switches the draft mode and updates clock + style for a live draft" do
    create_nfl_season(team_count: 4)
    create_league_via_http(your_name: "Alice", opponent_name: "Bob", draft_mode: "manual")
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    league = League.last
    ls = league.current_league_season

    patch league_path(league), params: {
      league: {name: league.name},
      league_season: {
        draft_mode: "live",
        draft_order_style: "snake",
        pick_clock_seconds: "45",
        draft_scheduled_at: "2026-12-01T10:00"
      }
    }

    expect(response).to redirect_to(league_path(league.reload))
    ls.reload
    expect(ls.draft_mode).to eq("live")
    expect(ls.draft_order_style).to eq("snake")
    expect(ls.pick_clock_seconds).to eq(45)
    expect(ls.draft_scheduled_at).to be_present
  end

  it "clears live-only fields when switching back to manual" do
    create_nfl_season(team_count: 4)
    create_league_via_http(your_name: "Alice", opponent_name: "Bob",
      draft_mode: "live", pick_clock_seconds: 60, draft_scheduled_at: "2026-12-01T10:00")
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    league = League.last
    ls = league.current_league_season

    patch league_path(league), params: {
      league: {name: league.name},
      league_season: {draft_mode: "manual"}
    }

    ls.reload
    expect(ls.draft_mode).to eq("manual")
    expect(ls.pick_clock_seconds).to be_nil
    expect(ls.draft_scheduled_at).to be_nil
  end

  it "ignores draft-config changes once any pick exists" do
    season = create_nfl_season(team_count: 4)
    create_league_via_http(your_name: "Alice", opponent_name: "Bob", draft_mode: "manual")
    post registration_path, params: {
      user: {email_address: "alice@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }
    league = League.last
    ls = league.current_league_season
    ls.update!(status: "drafting", draft_started_at: Time.current)
    owner = league.participants.find_by(is_owner: true)
    Drafts::SubmitPick.call(league_season: ls, season_team: season.season_teams.first)

    patch league_path(league), params: {
      league_season: {draft_mode: "live", pick_clock_seconds: "20"}
    }

    ls.reload
    expect(ls.draft_mode).to eq("manual")
    expect(ls.pick_clock_seconds).to be_nil
    owner # silence unused warning if any
  end

  it "blocks non-owners with accounts" do
    # Create league out-of-band so Alice's owner cookie never enters this
    # test session. Then Bob claims his seat and signs up — only Bob's
    # claim token is in the cookie.
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(your_name: "Alice", opponent_name: "Bob", season: season).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    post registration_path, params: {
      user: {email_address: "bob@example.com", password: "supersecret", password_confirmation: "supersecret"}
    }

    get edit_league_path(league)

    expect(response).to redirect_to(league_path(league))
  end
end
