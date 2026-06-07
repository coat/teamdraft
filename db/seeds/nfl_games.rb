# frozen_string_literal: true

# Loads a snapshot of the 2025 NFL regular + post season into the local DB so
# developers can work on scoring, leagues, and rosters without hitting
# thesportsdb. Idempotent: games are upserted by (season_id, external_id).
#
# The data lives in db/seeds/nfl_2025_games.json (~285 games) and was dumped
# from a populated dev database. Each row references teams by abbreviation
# so the loader is portable across environments.

module Seeds
  module NflGames
    SEASON_YEAR = 2025
    DATA_PATH = Rails.root.join("db/seeds/nfl_2025_games.json")

    def self.call
      sport = Sport.find_by(key: "nfl")
      return warn_missing("NFL sport not installed; run sports:install[nfl] first.") unless sport

      season = ensure_season(sport)
      season_team_ids = ensure_season_teams(sport, season)
      load_games(season, season_team_ids)
    end

    def self.ensure_season(sport)
      sport.seasons.find_or_create_by!(year: SEASON_YEAR) do |s|
        s.label = "#{SEASON_YEAR} NFL Season"
        s.starts_on = Date.new(SEASON_YEAR, 9, 1)
        s.ends_on = Date.new(SEASON_YEAR + 1, 2, 28)
        s.status = "completed"
      end
    end

    def self.ensure_season_teams(sport, season)
      sport.teams.each_with_object({}) do |team, ids|
        st = season.season_teams.find_or_create_by!(team: team)
        ids[team.abbreviation] = st.id
      end
    end

    def self.load_games(season, season_team_ids)
      games = JSON.parse(DATA_PATH.read)
      created = updated = 0
      games.each do |row|
        home_id = season_team_ids.fetch(row.fetch("home_abbr"))
        away_id = season_team_ids.fetch(row.fetch("away_abbr"))
        starts_at = Time.iso8601(row.fetch("starts_at"))
        completed = (row["status"] == "final") ? starts_at + 3.hours : nil
        game = season.games.find_or_initialize_by(external_id: row.fetch("external_id"))
        existed = game.persisted?
        game.assign_attributes(
          home_season_team_id: home_id,
          away_season_team_id: away_id,
          round: row.fetch("round"),
          week: row["week"],
          status: row.fetch("status"),
          home_score: row["home_score"],
          away_score: row["away_score"],
          starts_at: starts_at,
          completed_at: completed
        )
        next unless game.changed?
        game.save!
        existed ? (updated += 1) : (created += 1)
      end
      Rails.logger.info { "[seeds] NFL #{SEASON_YEAR} games: #{created} created, #{updated} updated, #{games.size} total." }
    end

    def self.warn_missing(message)
      Rails.logger.warn { "[seeds] #{message}" }
    end
  end
end
