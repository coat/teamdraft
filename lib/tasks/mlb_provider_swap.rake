# frozen_string_literal: true

# One-off swap from TheSportsDB to MLB Stats API for MLB.
#
# Steps (idempotent enough to re-run, though step 2 destructively deletes
# games each run):
#   1. Realign MLB team external_ids via the existing sports:realign task.
#   2. For every MLB season, set external_provider = "mlb_stats_api" and
#      external_id = season.year.to_s, and delete the season's games so
#      the next Sync::GamesJob (or RefreshActiveSeasonsJob tick) can
#      repopulate them by MLB gamePk.
#
# Usage:
#   bin/rails mlb:swap_to_stats_api
#   bin/rails sync:perform[<mlb_season_id>]   # or wait for the recurring job
namespace :mlb do
  desc "Swap MLB integration from TheSportsDB to MLB Stats API (destructive: wipes MLB games)"
  task swap_to_stats_api: :environment do
    sport = Sport.find_by(key: "mlb")
    abort "No MLB sport installed - run bin/rails sports:install[mlb] first." unless sport

    Rake::Task["sports:realign_external_ids"].invoke("mlb")

    seasons_updated = 0
    games_deleted = 0
    sport.seasons.find_each do |season|
      ApplicationRecord.transaction do
        games_deleted += season.games.count
        season.games.delete_all
        season.update!(external_provider: "mlb_stats_api", external_id: season.year.to_s)
      end
      seasons_updated += 1
      puts "  season #{season.year}: provider -> mlb_stats_api, external_id -> #{season.year}, games wiped"
    end

    puts "[mlb:swap_to_stats_api] seasons updated: #{seasons_updated}, games deleted: #{games_deleted}"
    puts "Next: run Sync::GamesJob.perform_later(<season_id>) for each MLB season, or wait for Sync::RefreshActiveSeasonsJob."
  end
end
