# frozen_string_literal: true

# One-off swap from TheSportsDB to NBA.com (cdn.nba.com) for NBA.
#
# Steps (idempotent enough to re-run, though step 2 destructively deletes
# games each run):
#   1. Realign NBA team external_ids via the existing sports:realign task
#      (TheSportsDB ids -> NBA.com franchise ids).
#   2. For every NBA season, set external_provider = "nba_stats_api" and
#      external_id = season.year.to_s, and delete the season's games so
#      the next Sync::GamesJob (or RefreshActiveSeasonsJob tick) can
#      repopulate them by NBA gameId.
#
# Usage:
#   bin/rails nba:swap_to_stats_api
#   bin/rails sync:perform[<nba_season_id>]   # or wait for the recurring job
namespace :nba do
  desc "Swap NBA integration from TheSportsDB to NBA.com (destructive: wipes NBA games)"
  task swap_to_stats_api: :environment do
    sport = Sport.find_by(key: "nba")
    abort "No NBA sport installed - run bin/rails sports:install[nba] first." unless sport

    Rake::Task["sports:realign_external_ids"].invoke("nba")

    seasons_updated = 0
    games_deleted = 0
    sport.seasons.find_each do |season|
      ApplicationRecord.transaction do
        games_deleted += season.games.count
        season.games.delete_all
        season.update!(external_provider: "nba_stats_api", external_id: season.year.to_s)
      end
      seasons_updated += 1
      puts "  season #{season.year}: provider -> nba_stats_api, external_id -> #{season.year}, games wiped"
    end

    puts "[nba:swap_to_stats_api] seasons updated: #{seasons_updated}, games deleted: #{games_deleted}"
    puts "Next: run Sync::GamesJob.perform_later(<season_id>) for each NBA season, or wait for Sync::RefreshActiveSeasonsJob."
  end
end
