# frozen_string_literal: true

module Invites
  # Atomically claims a Participant seat for a visitor: stamps joined_at,
  # records the optional user, adds the seat's claim token to the visitor's
  # cookie, and kicks the draft if both seats are now filled.
  #
  # Shared by the manual seat-picker (#claim action) and the auto-claim
  # path that fires when a verified invitee lands on a league with one
  # unclaimed seat.
  class ClaimSeat
    def self.call(...) = new(...).call

    def initialize(seat:, user:, participant_claims:)
      @seat = seat
      @user = user
      @participant_claims = participant_claims
    end

    def call
      @seat.update!(joined_at: Time.current, user: @user)
      @participant_claims.add(@seat.claim_token)
      Drafts::StartIfReady.call(league_season: @seat.league_season)
      @seat
    end
  end
end
