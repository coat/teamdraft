# frozen_string_literal: true

# Helpers for request specs that need a league + an authenticated participant
# (via the signed cookie). We drive through real HTTP requests rather than
# constructing the signed cookie manually, since Rack::Test's CookieJar
# doesn't expose `signed`.
module LeagueRequestHelpers
  def create_league_via_http(your_name: "Alice", opponent_name: "Bob", **extra)
    post "/leagues", params: {league: {your_name:, opponent_name:, **extra}}
    raise "league creation failed" unless response.redirect?
    League.find_by!(slug: response.location.split("/").last)
  end

  def claim_seat_via_http(league, seat)
    code = league.current_league_season.invite_code
    post verify_invite_league_path(league), params: {code: code}
    post claim_league_path(league), params: {seat_id: seat.id}
  end
end

RSpec.configure do |config|
  config.include LeagueRequestHelpers, type: :request
end
