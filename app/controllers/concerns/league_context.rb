# frozen_string_literal: true

# Shared `before_action` plumbing for controllers scoped to a single league
# (either as a top-level resource via `:id` or nested via `:league_id`).
#
# Provides `load_league`, `load_league_season`, and `require_owner` so each
# controller doesn't reinvent friendly-find lookups, season redirect-on-nil
# handling, and the participant-ownership check.
module LeagueContext
  extend ActiveSupport::Concern

  included do
    class_attribute :owner_alert,
      default: "Only the league owner can edit this league."
  end

  private

  def load_league
    @league = League.friendly.find(params[:league_id] || params[:id])
  end

  def load_league_season
    @league_season = @league.current_league_season
    return if @league_season
    redirect_to league_path(@league), alert: "No active season for this league."
  end

  def require_owner
    return if current_participant_for(@league)&.is_owner?
    redirect_to league_path(@league), alert: self.class.owner_alert
  end
end
