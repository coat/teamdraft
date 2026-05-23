# frozen_string_literal: true

module Invites
  # Wraps the per-session record of which LeagueSeason invite codes have
  # been entered correctly in this browser. Verification gates the seat-
  # claim UI so a visitor who only knows the league URL can't claim a
  # seat without the code.
  #
  # The session value is shaped like `{"42" => true, "43" => true}`. We
  # defend the read against non-Hash values (a session may pre-date this
  # key) but use `||=` on the write to match the historical behavior.
  class Verifications
    SESSION_KEY = :verified_invites

    def initialize(session)
      @session = session
    end

    def verified?(league_season)
      return false unless league_season
      store[league_season.id.to_s] == true
    end

    def mark!(league_season)
      return unless league_season
      @session[SESSION_KEY] ||= {}
      @session[SESSION_KEY][league_season.id.to_s] = true
    end

    private

    def store
      raw = @session[SESSION_KEY]
      raw.is_a?(Hash) ? raw : {}
    end
  end
end
