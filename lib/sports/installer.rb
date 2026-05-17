# frozen_string_literal: true

# Idempotent installer for a sport's reference data. Used by:
#   bin/rails sports:install[nba]
#
# Designed to be safe to re-run in production: existing records are never
# overwritten on subsequent runs. New records (teams added mid-season, new
# scoring rules, the next season) are created on demand.
#
# Each new sport (MLB, NHL, …) just needs a config under lib/sports/configs/
# and an entry in Sports::Installer::SUPPORTED.

module Sports
  class Installer
    SUPPORTED = %w[nfl nba].freeze

    Result = Struct.new(:sport, :created, :existed, :seasons, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(key:, config:, logger: Rails.logger)
      @key = key.to_s
      @config = config
      @logger = logger
      @created = Hash.new(0)
      @existed = Hash.new(0)
    end

    def call
      ApplicationRecord.transaction do
        sport = install_sport
        install_teams(sport)
        install_scoring_rules(sport)
        season = install_current_season(sport)
        install_season_teams(season) if season
        Result.new(sport: sport, created: @created, existed: @existed, seasons: [season].compact)
      end
    ensure
      log_summary
    end

    private

    def install_sport
      existing = Sport.find_by(key: @key)
      if existing
        @existed[:sport] += 1
        # Backfill nullable display fields if they were never set, but don't
        # clobber values an admin may have edited (name, active).
        existing.update!(about_blurb: @config.about_blurb) if existing.about_blurb.blank? && @config.about_blurb.present?
        return existing
      end
      @created[:sport] += 1
      Sport.create!(key: @key, name: @config.name, about_blurb: @config.about_blurb, active: true)
    end

    def install_teams(sport)
      @config.teams.each do |attrs|
        if sport.teams.exists?(slug: attrs[:slug])
          @existed[:team] += 1
          next
        end
        sport.teams.create!(attrs)
        @created[:team] += 1
      end
    end

    def install_scoring_rules(sport)
      @config.scoring_rules.each do |attrs|
        if sport.scoring_rules.exists?(event_type: attrs[:event_type])
          @existed[:scoring_rule] += 1
          next
        end
        sport.scoring_rules.create!(attrs)
        @created[:scoring_rule] += 1
      end
    end

    # Install the season that should be considered "current" for league
    # creation right now. Returns nil if the config doesn't specify season
    # bounds (e.g. for sports we want to seed teams/rules for but not yet
    # offer in the dropdown).
    def install_current_season(sport)
      return nil unless @config.respond_to?(:current_season) && @config.current_season
      attrs = @config.current_season.call(Date.current)
      season = sport.seasons.find_by(year: attrs[:year])
      if season
        @existed[:season] += 1
        return season
      end
      @created[:season] += 1
      sport.seasons.create!(attrs.merge(status: "active"))
    end

    def install_season_teams(season)
      season.sport.teams.find_each do |team|
        if SeasonTeam.exists?(season_id: season.id, team_id: team.id)
          @existed[:season_team] += 1
          next
        end
        SeasonTeam.create!(season: season, team: team)
        @created[:season_team] += 1
      end
    end

    def log_summary
      parts = (@created.keys | @existed.keys).map { |k|
        "#{k}=+#{@created[k]}/=#{@existed[k]}"
      }.join(" ")
      @logger.info "[sports:install #{@key}] #{parts}"
    end
  end
end
