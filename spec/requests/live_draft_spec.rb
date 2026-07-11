# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Live draft", type: :request do
  it "Bob can't pick when Alice (pick #1) is on the clock" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    season_team = season.season_teams.first

    expect { post league_draft_picks_path(league), params: {season_team_id: season_team.id} }
      .not_to change(DraftPick, :count)

    follow_redirect!
    expect(response.body).to include("not your turn")
  end

  it "renders the unified team directory as a turbo frame" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    Drafts::SubmitPick.call(league_season: league.reload.current_league_season, season_team: season.season_teams.first)

    get league_draft_path(league)

    expect(response.body).to include("<turbo-frame")
    expect(response.body).to include('id="team_directory"')
    expect(response.body).not_to match(%r{<select[^>]*name="season_team_id"})
  end

  it "still renders the directory when it's not your turn but hides Pick buttons" do
    create_nfl_season(team_count: 4)
    league = create_league_via_http(your_name: "Alice", opponent_name: "Bob",
      draft_mode: "live", pick_clock_seconds: 30)
    bob_seat = league.participants.find_by(draft_position: 2)
    reset!
    claim_seat_via_http(league, bob_seat)
    get league_draft_path(league)

    expect(response.body).to include('id="team_directory"')
    expect(response.body).not_to match(%r{<form[^>]*action="/leagues/[^"?]+/draft_picks})
  end

  it "marks a picked team's row with the picker and pick number" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    ls = league.reload.current_league_season
    Drafts::SubmitPick.call(league_season: ls, season_team: season.season_teams.first)

    # status=all so the picked team isn't filtered out by the default
    get league_draft_path(league, status: "")

    expect(response.body).to match(/##{ls.reload.draft_picks.first.pick_number}\b/)
    expect(response.body).to include("Alice")
  end

  it "sorts rows server-side via ?sort and ?dir" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)

    get league_draft_path(league, sort: "name", dir: "desc")

    body = response.body[response.body.index("<turbo-frame")..response.body.index("</turbo-frame>")]
    ordered = body.scan(%r{<td class="font-medium">(Team \d+)</td>})
    expect(ordered.flatten).to eq(["Team 4", "Team 3", "Team 2", "Team 1"])
  end

  it "preserves filter params across the post-pick redirect" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)

    post league_draft_picks_path(league, sort: "name", dir: "desc"),
      params: {season_team_id: season.season_teams.first.id, pick_number: 1}

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("sort=name")
    expect(response.location).to include("dir=desc")
  end

  it "shows a boxed countdown for a draft scheduled in the future" do
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30,
      draft_scheduled_at: 2.hours.from_now
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)

    get league_draft_path(league)

    expect(response.body).to include('data-draft-clock-mode-value="boxes"')
    expect(response.body).to include('class="countdown font-mono text-4xl"')
  end

  it "Bob can pick on pick #2 (back-and-forth order)" do
    # Bob claims his seat (which fills both seats and transitions the
    # league to drafting). Then submit Alice's pick #1 server-side and let
    # Bob pick #2 over HTTP under his own cookie.
    season = create_nfl_season(team_count: 4)
    league = Leagues::Create.call(
      your_name: "Alice", opponent_name: "Bob", season: season,
      draft_mode: "live", pick_clock_seconds: 30
    ).first
    bob_seat = league.participants.find_by(draft_position: 2)
    claim_seat_via_http(league, bob_seat)
    Drafts::SubmitPick.call(league_season: league.reload.current_league_season, season_team: season.season_teams.first)

    expect { post league_draft_picks_path(league), params: {season_team_id: season.season_teams.second.id, pick_number: 2} }
      .to change(DraftPick, :count).by(1)
  end
end
