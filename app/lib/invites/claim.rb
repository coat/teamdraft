# frozen_string_literal: true

module Invites
  # Handles an invite-code submission. If the code matches, marks the
  # session as verified and - when the visitor isn't already a
  # participant and exactly one seat is open - auto-claims it on their
  # behalf, skipping the manual "are you {name}?" picker.
  #
  # Returns a Result so callers can branch on:
  #   - verified?      did the code match
  #   - auto_claimed?  did we silently take the lone open seat
  class Claim
    Result = Data.define(:verified, :claimed_seat) do
      def verified? = verified

      def auto_claimed? = !claimed_seat.nil?
    end

    NOT_VERIFIED = Result.new(verified: false, claimed_seat: nil).freeze

    def self.call(...) = new(...).call

    def initialize(league_season:, code:, user:, current_participant:,
      participant_claims:, verifications:)
      @league_season = league_season
      @code = code
      @user = user
      @current_participant = current_participant
      @participant_claims = participant_claims
      @verifications = verifications
    end

    def call
      return NOT_VERIFIED unless @league_season&.verify_invite!(@code.to_s)
      @verifications.mark!(@league_season)
      Result.new(verified: true, claimed_seat: maybe_auto_claim)
    end

    private

    def maybe_auto_claim
      return nil if @current_participant
      open_seats = @league_season.participants.where(joined_at: nil).to_a
      return nil unless open_seats.size == 1
      ClaimSeat.call(
        seat: open_seats.first,
        user: @user,
        participant_claims: @participant_claims
      )
    end
  end
end
