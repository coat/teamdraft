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

# Optional: load completed-season game fixtures so local devs can work on
# scoring/leagues without thesportsdb. Safe to re-run. MLB ships postseason
# only — the free tier can't deliver a full 2,430-game regular season.
require Rails.root.join("db/seeds/nfl_games")
Seeds::NflGames.call
require Rails.root.join("db/seeds/mlb_games")
Seeds::MlbGames.call
