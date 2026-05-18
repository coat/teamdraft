# frozen_string_literal: true

# Bootstrap reference data for every supported sport. Idempotent — re-running
# only fills in missing rows; existing teams, scoring rules, seasons and
# season_teams are left untouched. New sports plug in via lib/sports/configs/
# (see Sports::Installer). For one-off installs in an already-seeded
# environment, prefer `bin/rails sports:install[<key>]` over re-running seeds.

Sports::Installer::SUPPORTED.each do |key|
  config = "Sports::Configs::#{key.capitalize}".constantize.build
  Sports::Installer.call(key: key, config: config)
end

# Optional: load a completed NFL season's worth of games so local devs can
# work on scoring/leagues without thesportsdb. Safe to re-run.
require Rails.root.join("db/seeds/nfl_games")
Seeds::NflGames.call
