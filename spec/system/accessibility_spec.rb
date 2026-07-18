# frozen_string_literal: true

require "rails_helper"

# Axe (WCAG 2.1 A/AA) scans of the key pages. These catch structural
# regressions - missing labels/landmarks, contrast, bad ARIA - not
# behavioral ones like live-region announcements, which need manual checks.
# Cuprite/axe bridging lives in spec/support/axe.rb.
RSpec.describe "Accessibility", :js, type: :system do
  def expect_axe_clean
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  def sign_in_via_form(user)
    visit "/session/new"
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "supersecret"
    click_button "Sign in"
    expect(page).to have_no_current_path("/session/new")
  end

  it "scans the landing page" do
    create_nfl_season(status: "active")
    visit "/"
    expect_axe_clean
  end

  it "scans sign-in and registration" do
    visit "/session/new"
    expect_axe_clean
    visit "/registration/new"
    expect_axe_clean
  end

  it "scans season standings (both views)" do
    season = create_nfl_season(team_count: 4)
    season.season_teams.each { |st| st.team.update!(conference: "AFC", division: "West") }
    visit "/seasons/#{season.sport.key}/#{season.year}"
    expect_axe_clean
    visit "/seasons/#{season.sport.key}/#{season.year}?view=division"
    expect_axe_clean
  end

  it "scans the draft room while drafting" do
    season = create_nfl_season(team_count: 4)
    league_season = create(:league_season, :with_two_participants, season: season)
    start_drafting!(league_season)
    visit "/leagues/#{league_season.league.slug}/draft"
    expect_axe_clean
  end

  it "scans rankings for a signed-in user" do
    season = create_nfl_season(team_count: 4)
    sign_in_via_form(create(:user))
    visit "/rankings/#{season.sport.key}"
    expect_axe_clean
  end

  it "scans an admin index" do
    create_nfl_season(team_count: 2)
    sign_in_via_form(create(:user, admin: true))
    visit "/admin/teams"
    expect_axe_clean
  end
end
