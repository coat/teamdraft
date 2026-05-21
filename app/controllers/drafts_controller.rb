# frozen_string_literal: true

class DraftsController < ApplicationController
  before_action :load_league
  before_action :load_league_season
  before_action :require_owner, only: [:edit, :update]

  def show
    # Defensive self-heal: a deep link to /draft might arrive before anyone
    # touched /leagues/:id. StartIfReady is idempotent.
    if @league_season.status == "draft_pending"
      Drafts::StartIfReady.call(league_season: @league_season)
      @league_season.reload
    end

    # Don't redirect finished drafts away from /draft — the auto-pick
    # broadcast fires a Turbo refresh of the *current* URL, and Turbo
    # morphing across a redirect-to-a-different-page leaves stale UI
    # (the "auto-picking…" clock stays on screen). Render an in-place
    # "draft complete" state instead; Views::Drafts::Show has a CTA
    # back to the standings page.
    render Views::Drafts::Show.new(
      league: @league,
      league_season: @league_season,
      current_participant: current_participant_for(@league),
      directory_query: build_directory_query
    )
  end

  def edit
    render Views::Drafts::Edit.new(league: @league, league_season: @league_season)
  end

  def update
    if @league_season.draft_picks.any?
      redirect_to league_path(@league), alert: "Draft has started — settings are locked."
      return
    end

    attrs = league_season_params.to_h
    if attrs[:draft_scheduled_at].present?
      attrs[:draft_scheduled_at] = parsed_local_datetime(
        attrs[:draft_scheduled_at],
        params.dig(:league_season, :time_zone)
      )
    end
    @league_season.assign_attributes(attrs)
    normalize_draft_mode_switch(@league_season)
    @league_season.save!
    redirect_to league_path(@league), notice: "Draft settings updated."
  rescue ActiveRecord::RecordInvalid
    render Views::Drafts::Edit.new(league: @league, league_season: @league_season),
      status: :unprocessable_entity
  end

  private

  def load_league
    @league = League.friendly.find(params[:league_id])
  end

  def load_league_season
    @league_season = @league.current_league_season
    unless @league_season
      redirect_to league_path(@league), alert: "No active season for this league."
    end
  end

  def require_owner
    participant = current_participant_for(@league)
    unless participant&.is_owner?
      redirect_to league_path(@league),
        alert: "Only the league owner can edit this league."
    end
  end

  def league_season_params
    params.require(:league_season).permit(:draft_mode, :draft_order_style,
      :draft_scheduled_at, :pick_clock_seconds)
  end

  def normalize_draft_mode_switch(league_season)
    case league_season.draft_mode
    when "manual"
      league_season.pick_clock_seconds = nil
      league_season.draft_scheduled_at = nil
    end
  end

  def parsed_local_datetime(value, zone)
    return nil if value.blank?
    if zone.present?
      ActiveSupport::TimeZone[zone]&.parse(value) || value
    else
      value
    end
  end

  def build_directory_query
    Leagues::DirectoryQuery.new(
      league_season: @league_season,
      params: params.permit(:sort, :dir, :status, :division),
      user: current_user
    )
  end
end
