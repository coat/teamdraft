# frozen_string_literal: true

module DraftHelpers
  # Fills any unjoined seats and transitions the league to "drafting".
  # Most specs need a fully-claimed, started draft as their starting point;
  # this is the cheapest way to get there without going through the HTTP
  # claim flow.
  def start_drafting!(league)
    league.participants.where(joined_at: nil).update_all(joined_at: Time.current)
    league.update!(draft_scheduled_at: nil) if league.draft_scheduled_at.present?
    Drafts::StartIfReady.call(league: league.reload)
    league.reload
  end
end

RSpec.configure do |config|
  config.include DraftHelpers
end
