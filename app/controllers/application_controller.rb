# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include SeasonPaths

  allow_browser versions: :modern

  helper_method :participant_claims, :current_participant_for

  def participant_claims
    @participant_claims ||= ParticipantClaims.new(cookies)
  end

  def current_participant_for(league)
    @current_participant_for ||= {}
    @current_participant_for[league.id] ||= resolve_current_participant(league)
  end

  def resolve_current_participant(league)
    ls = league.current_league_season
    return nil unless ls
    participant_claims.participant_for(league) ||
      current_user&.participants&.find_by(league_season_id: ls.id)
  end
end
