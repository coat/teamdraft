# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  helper_method :participant_claims, :current_participant_for

  def participant_claims
    @participant_claims ||= ParticipantClaims.new(cookies)
  end

  def current_participant_for(league)
    @current_participant_for ||= {}
    @current_participant_for[league.id] ||=
      participant_claims.participant_for(league) ||
      current_user&.participants&.find_by(league_id: league.id)
  end
end
