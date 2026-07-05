# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Season view", :js, type: :system do
  it "keeps a row's breakdown expanded across view tab switches" do
    season = create_nfl_season(team_count: 2)
    season.season_teams.each { |st| st.team.update!(conference: "AFC", division: "West") }
    season_team = season.season_teams.first
    panel = "season-breakdown-#{season_team.id}"

    visit "/seasons/#{season.sport.key}/#{season.year}"
    find("button[aria-controls='#{panel}']").click
    expect(page).to have_selector("tr##{panel}:not(.hidden)")

    click_link "By division"
    expect(page).to have_current_path(/view=division/)
    expect(page).to have_selector("tr##{panel}:not(.hidden)")

    click_link "Standings"
    expect(page).to have_no_current_path(/view=division/)
    expect(page).to have_selector("tr##{panel}:not(.hidden)")
  end

  it "keeps scroll position and expansion when sorting a division table" do
    season = create_nfl_season(team_count: 32)
    conferences = %w[AFC NFC]
    divisions = %w[East North South West]
    season.season_teams.each_with_index do |st, i|
      st.team.update!(conference: conferences[i % 2], division: divisions[(i / 2) % 4])
    end
    season_team = season.season_teams.first
    panel = "season-breakdown-#{season_team.id}"

    visit "/seasons/#{season.sport.key}/#{season.year}?view=division"
    find("button[aria-controls='#{panel}']").click
    expect(page).to have_selector("tr##{panel}:not(.hidden)")

    page.execute_script("window.scrollTo(0, 300)")
    scrolled = page.evaluate_script("window.scrollY")
    expect(scrolled).to be > 0

    first("th a", text: "Team").click
    expect(page).to have_current_path(/sort=name/)

    expect(page).to have_selector("tr##{panel}:not(.hidden)")
    expect(page.evaluate_script("window.scrollY")).to eq(scrolled)
  end
end
