# frozen_string_literal: true

class ParticipantsController < ApplicationController
  include LeagueContext

  self.owner_alert = "Only the league owner can change the draft order."

  before_action :load_league
  before_action :load_league_season
  before_action :require_owner
  before_action :load_participant

  def move_up
    move(:up, edge: "first")
  end

  def move_down
    move(:down, edge: "last")
  end

  private

  def move(direction, edge:)
    return redirect_locked if draft_started?

    moved = (direction == :up) ? @participant.move_up! : @participant.move_down!
    if moved
      redirect_to edit_league_draft_path(@league),
        notice: "Moved #{@participant.display_name} #{direction}."
    else
      redirect_to edit_league_draft_path(@league),
        alert: "#{@participant.display_name} is already #{edge}."
    end
  end

  def load_participant
    @participant = @league_season.participants.find(params[:id])
  end

  def draft_started?
    @league_season.draft_picks.any?
  end

  def redirect_locked
    redirect_to edit_league_draft_path(@league),
      alert: "Draft has started - the order is locked."
  end
end
