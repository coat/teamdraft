# frozen_string_literal: true

require_relative "seeds/nfl_teams"

ActiveRecord::Base.transaction do
  nfl_scoring_rules = {
    "regular_win" => 1,
    "playoff_appearance" => 5,
    "divisional_appearance" => 5,
    "conference_appearance" => 10,
    "championship_appearance" => 10,
    "championship_win" => 5
  }
  nfl = Sport.find_or_initialize_by(key: "nfl")
  nfl.name = "NFL"
  nfl.scoring_rules = nfl_scoring_rules
  nfl.save!

  Seeds::NflTeams::DATA.each do |attrs|
    team = Team.find_or_initialize_by(sport_id: nfl.id, slug: attrs[:slug])
    team.assign_attributes(attrs)
    team.save!
  end

  current_year = Date.current.year
  season_year = (Date.current.month >= 9) ? current_year : current_year - 1

  season = Season.find_or_create_by!(sport_id: nfl.id, year: season_year) do |s|
    s.label = "#{season_year} NFL Season"
    s.starts_on = Date.new(season_year, 9, 1)
    s.ends_on = Date.new(season_year + 1, 2, 28)
    s.status = "active"
  end

  nfl.teams.find_each do |team|
    SeasonTeam.find_or_create_by!(season_id: season.id, team_id: team.id)
  end

  Rails.logger.info "[seeds] Sport=#{nfl.key} season=#{season.year} teams=#{nfl.teams.count} season_teams=#{season.season_teams.count}"
end
