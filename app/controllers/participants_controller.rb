# frozen_string_literal: true

class ParticipantsController < ApplicationController
  before_action :load_league
  before_action :require_owner
  before_action :load_participant

  def move_up
    return redirect_locked if draft_started?

    swap_with = adjacent_seat(:above)
    if swap_with
      swap_positions(@participant, swap_with)
      redirect_to edit_league_path(@league), notice: "Moved #{@participant.display_name} up."
    else
      redirect_to edit_league_path(@league), alert: "#{@participant.display_name} is already first."
    end
  end

  def move_down
    return redirect_locked if draft_started?

    swap_with = adjacent_seat(:below)
    if swap_with
      swap_positions(@participant, swap_with)
      redirect_to edit_league_path(@league), notice: "Moved #{@participant.display_name} down."
    else
      redirect_to edit_league_path(@league), alert: "#{@participant.display_name} is already last."
    end
  end

  private

  def load_league
    @league = League.friendly.find(params[:league_id])
    @league_season = @league.current_league_season
  end

  def require_owner
    participant = current_participant_for(@league)
    unless participant&.is_owner?
      redirect_to league_path(@league),
        alert: "Only the league owner can change the draft order."
    end
  end

  def load_participant
    @participant = @league_season.participants.find(params[:id])
  end

  def draft_started?
    @league_season.draft_picks.any?
  end

  def redirect_locked
    redirect_to edit_league_path(@league),
      alert: "Draft has started — the order is locked."
  end

  def adjacent_seat(direction)
    scope = @league_season.participants.where.not(id: @participant.id)
    if direction == :above
      scope.where(draft_position: ...@participant.draft_position)
        .order(draft_position: :desc).first
    else
      scope.where(draft_position: (@participant.draft_position + 1)..)
        .order(draft_position: :asc).first
    end
  end

  # Defer the (league_season_id, draft_position) uniqueness constraint to
  # the end of the transaction so two row updates can swap values without
  # tripping the per-row check. update_columns also bypasses the model-level
  # uniqueness validator; we manually broadcast since callbacks are skipped.
  def swap_positions(a, b)
    Participant.transaction do
      Participant.connection.execute("SET CONSTRAINTS ALL DEFERRED")
      a_pos = a.draft_position
      a.update_columns(draft_position: b.draft_position)
      b.update_columns(draft_position: a_pos)
    end
    Turbo::StreamsChannel.broadcast_refresh_later_to(@league)
  end
end
