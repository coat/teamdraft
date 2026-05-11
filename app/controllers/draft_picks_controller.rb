# frozen_string_literal: true

class DraftPicksController < ApplicationController
  before_action :load_league
  before_action :require_authorized_picker

  def create
    season_team = @league.season.season_teams.find(params[:season_team_id])
    Drafts::SubmitPick.call(league: @league, season_team:)
    redirect_to league_path(@league)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to league_path(@league), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def load_league
    @league = League.friendly.find(params[:league_id])
  end

  def require_authorized_picker
    participant = current_participant_for(@league)
    return unauthorized!("Claim a seat to draft.") unless participant

    case @league.draft_mode
    when "manual"
      unauthorized!("Only the league owner can record picks in a manual draft.") unless participant.is_owner?
    when "live"
      on_clock = clock_participant
      unauthorized!("It's not your turn yet.") unless on_clock && participant.id == on_clock.id
    end
  end

  def clock_participant
    return nil if @league.current_pick_number > @league.total_picks
    pos = Drafts::Order.position_for(
      pick_number: @league.current_pick_number,
      size: @league.size,
      style: @league.draft_order_style
    )
    @league.participants.find_by(draft_position: pos)
  end

  def unauthorized!(message)
    redirect_to league_path(@league), alert: message
  end
end
