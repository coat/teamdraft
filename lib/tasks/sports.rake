# frozen_string_literal: true

# Idempotent sport installers. Designed to be safe to run in production:
# existing records are never overwritten — only missing ones are created.
#
# Typical use:
#   bin/rails sports:install[nba]   # add NBA to a running prod env
#   bin/rails sports:install_all    # one-shot for a fresh environment
#   bin/rails sports:list           # see which sports the installer knows
#
# To add a new sport (MLB, NHL, …):
#   1. drop a team fixture in db/seeds/<sport>_teams.rb
#   2. add lib/sports/configs/<sport>.rb returning a Sports::Config
#   3. add the key to Sports::Installer::SUPPORTED
#   4. run bin/rails sports:install[<sport>]
namespace :sports do
  desc "Install or backfill a single sport (key = nfl, nba, …)"
  task :install, [:key] => :environment do |_, args|
    key = args[:key].to_s
    require_supported!(key)
    config = build_config(key)
    result = Sports::Installer.call(key: key, config: config)
    puts format_result(result)
  end

  desc "Install or backfill every supported sport"
  task install_all: :environment do
    Sports::Installer::SUPPORTED.each do |key|
      config = build_config(key)
      result = Sports::Installer.call(key: key, config: config)
      puts format_result(result)
    end
  end

  desc "Realign teams.external_id to the values in the installer config (key)"
  # Use when an upstream provider id was wrong in a prior seed and existing
  # rows need to be patched without rewriting any other admin-managed
  # attributes (default_pick_rank, primary_color, etc.). Matches by slug.
  task :realign_external_ids, [:key] => :environment do |_, args|
    key = args[:key].to_s
    require_supported!(key)
    config = build_config(key)
    sport = Sport.find_by!(key: key)
    # Two-phase to dodge the (sport_id, external_id) uniqueness index when
    # values are being swapped between rows: null everything we plan to
    # change, then re-assign.
    plan = config.teams.filter_map { |attrs|
      team = sport.teams.find_by(slug: attrs[:slug])
      next unless team
      next if team.external_id == attrs[:external_id]
      [team, team.external_id, attrs[:external_id]]
    }
    ApplicationRecord.transaction do
      plan.each { |team, _, _| team.update_columns(external_id: nil) }
      plan.each do |team, old, new_id|
        team.update!(external_id: new_id)
        puts "  #{team.slug}: #{old.inspect} -> #{new_id.inspect}"
      end
    end
    puts "[#{key}] updated #{plan.size} team(s)"
  end

  desc "List sports the installer knows how to build"
  task list: :environment do
    Sports::Installer::SUPPORTED.each do |key|
      installed = Sport.exists?(key: key) ? "✓ installed" : "  not installed"
      puts "  #{key.ljust(6)} #{installed}"
    end
  end
end

def require_supported!(key)
  return if Sports::Installer::SUPPORTED.include?(key)
  abort "Unknown sport #{key.inspect}. Supported: #{Sports::Installer::SUPPORTED.join(", ")}"
end

def build_config(key)
  "Sports::Configs::#{key.capitalize}".constantize.build
end

def format_result(result)
  c = result.created.map { |k, v| "+#{v} #{k}" if v.positive? }.compact.join(", ")
  e = result.existed.map { |k, v| "#{v} #{k} already present" if v.positive? }.compact.join(", ")
  pieces = [
    "[#{result.sport.key}]",
    c.presence,
    e.present? ? "(#{e})" : nil
  ].compact
  pieces.join(" ")
end
