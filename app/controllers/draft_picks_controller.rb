# frozen_string_literal: true

class DraftPicksController < ApplicationController
  before_action :load_league_season
  before_action :require_authorized_picker

  def create
    season_team = @league_season.season.season_teams.find(params[:season_team_id])
    Drafts::SubmitPick.call(league_season: @league_season, season_team:)
    redirect_to league_path(@league)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to league_path(@league), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def load_league_season
    @league = League.friendly.find(params[:league_id])
    @league_season = @league.current_league_season
  end

  def require_authorized_picker
    participant = current_participant_for(@league)
    return unauthorized!("Claim a seat to draft.") unless participant

    case @league_season.draft_mode
    when "manual"
      unauthorized!("Only the league owner can record picks in a manual draft.") unless participant.is_owner?
    when "live"
      on_clock = clock_participant
      unauthorized!("It's not your turn yet.") unless on_clock && participant.id == on_clock.id
    end
  end

  def clock_participant
    return nil if @league_season.current_pick_number > @league_season.total_picks
    pos = Drafts::Order.position_for(
      pick_number: @league_season.current_pick_number,
      size: @league_season.size,
      style: @league_season.draft_order_style
    )
    @league_season.participants.find_by(draft_position: pos)
  end

  def unauthorized!(message)
    redirect_to league_path(@league), alert: message
  end
end
