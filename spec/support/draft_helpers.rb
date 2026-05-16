# frozen_string_literal: true

module DraftHelpers
  # Fills any unjoined seats and transitions the league season to "drafting".
  # Most specs need a fully-claimed, started draft as their starting point;
  # this is the cheapest way to get there without going through the HTTP
  # claim flow.
  def start_drafting!(league_season)
    league_season.participants.where(joined_at: nil).update_all(joined_at: Time.current)
    league_season.update!(draft_scheduled_at: nil) if league_season.draft_scheduled_at.present?
    Drafts::StartIfReady.call(league_season: league_season.reload)
    league_season.reload
  end
end

RSpec.configure do |config|
  config.include DraftHelpers
end
