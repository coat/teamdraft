# frozen_string_literal: true

class LeaguesController < ApplicationController
  include LeagueContext

  before_action :load_league, only: [:show, :claim, :edit, :update, :history, :verify_invite]
  before_action :enforce_canonical_url, only: :show
  before_action :require_owner, only: [:edit, :update]

  def index
    participants = participants_for_visitor
    if participants.empty?
      render Views::Pages::Home.new(league: new_league, seasons: selectable_seasons)
    else
      render Views::Leagues::Index.new(participants: participants)
    end
  end

  def new
    render_new_form
  end

  def create
    season = chosen_season
    return render_no_season unless season

    league, owner = Leagues::Create.call(
      your_name: params.dig(:league, :your_name),
      opponent_name: params.dig(:league, :opponent_name),
      season:,
      draft_scheduled_at: LocalDatetime.parse(
        params.dig(:league, :draft_scheduled_at),
        zone: params.dig(:league, :time_zone)
      ),
      draft_mode: params.dig(:league, :draft_mode).presence || "live",
      pick_clock_seconds: params.dig(:league, :pick_clock_seconds).presence,
      owner_user: current_user
    )
    participant_claims.add(owner.claim_token)
    redirect_to league_path(league), notice: "League created. Share this URL with your opponent."
  rescue ActiveRecord::RecordInvalid => e
    @league = e.record.is_a?(League) ? e.record : League.new
    @errors = e.record.errors.full_messages
    render Views::Leagues::New.new(league: @league, seasons: selectable_seasons, errors: @errors), status: :unprocessable_entity
  end

  def show
    @league_season = @league.current_league_season
    if params[:invite].present?
      if @league_season&.verify_invite!(params[:invite])
        mark_invite_verified(@league_season)
        claimed = auto_claim_lone_seat(@league_season)
        if claimed
          redirect_to league_path(@league), notice: "Welcome, #{claimed.display_name}." and return
        else
          redirect_to league_path(@league) and return
        end
      else
        flash.now[:alert] = "That invite code didn't match."
      end
    end

    # Two URLs, two intents: /leagues/:id is the standings/landing page;
    # /leagues/:id/draft is the draft room. Send claimed viewers to the
    # draft room once picking has started AND every seat is claimed.
    # An unclaimed seat means the share card is still load-bearing here
    # - manual drafts in particular flip to `drafting` the moment the
    # league is created, so the owner would never see the invite code
    # if we redirected on status alone.
    if @league_season&.status == "drafting" &&
        @league_season.participants.where(joined_at: nil).none? &&
        current_participant_for(@league).present?
      redirect_to league_draft_path(@league) and return
    end

    render Views::Leagues::Show.new(
      league: @league,
      league_season: @league_season,
      current_participant: current_participant_for(@league),
      invite_verified: invite_verified_for?(@league_season),
      directory_query: build_directory_query
    )
  end

  def edit
    @league_season = @league.current_league_season
    render Views::Leagues::Edit.new(league: @league, league_season: @league_season)
  end

  def update
    @league_season = @league.current_league_season
    @league.update!(league_params) if params[:league].present?
    redirect_to league_path(@league), notice: "League updated."
  rescue ActiveRecord::RecordInvalid
    render Views::Leagues::Edit.new(league: @league, league_season: @league_season),
      status: :unprocessable_entity
  end

  def history
    league_seasons = @league.league_seasons.includes(:season).order("seasons.year DESC").references(:season)
    render Views::Leagues::History.new(league: @league, league_seasons: league_seasons)
  end

  def claim
    league_season = @league.current_league_season
    unless invite_verified_for?(league_season)
      redirect_to league_path(@league), alert: "Enter the league's invite code to claim a seat."
      return
    end

    seat = league_season.participants.find(params[:seat_id])
    if seat.joined_at.present? || current_participant_for(@league).present?
      redirect_to league_path(@league), alert: "That seat is already claimed."
      return
    end

    seat.update!(joined_at: Time.current, user: current_user)
    participant_claims.add(seat.claim_token)
    Drafts::StartIfReady.call(league_season: league_season)
    redirect_to league_path(@league), notice: "Welcome, #{seat.display_name}."
  end

  def verify_invite
    league_season = @league.current_league_season
    code = params[:code].to_s
    if league_season&.verify_invite!(code)
      mark_invite_verified(league_season)
      claimed = auto_claim_lone_seat(league_season)
      if claimed
        redirect_to league_path(@league), notice: "Welcome, #{claimed.display_name}."
      else
        redirect_to league_path(@league)
      end
    else
      redirect_to league_path(@league), alert: "That invite code didn't match."
    end
  end

  private

  def render_new_form
    render Views::Leagues::New.new(league: new_league, seasons: selectable_seasons)
  end

  def new_league
    League.new(
      draft_scheduled_at: 5.minutes.from_now,
      draft_mode: "live",
      season_id: default_season&.id,
      your_name: default_your_name
    )
  end

  # Prefer a previously-used display name from any prior participant the
  # visitor owns (via cookie or user account). Returns nil for first-timers.
  def default_your_name
    participants_for_visitor.order(created_at: :desc).limit(1).pick(:display_name)
  end

  def participants_for_visitor
    user_ids = current_user ? Participant.where(user_id: current_user.id).pluck(:id) : []
    token_ids = Participant.where(claim_token: participant_claims.tokens).pluck(:id)
    Participant.where(id: (user_ids + token_ids).uniq).includes(league_season: [:league, :season])
  end

  # `friendly_id` lets old slugs keep resolving; redirect to the current slug
  # so canonical URLs are stable.
  def enforce_canonical_url
    return if request.path == league_path(@league)
    redirect_to league_path(@league), status: :moved_permanently
  end

  # Seasons offered in the league-creation dropdown: upcoming first (soonest
  # first), then active / in-progress (most-recently-started first).
  # Only the earliest upcoming season per sport is shown so future pre-created
  # seasons don't clutter the dropdown.
  def selectable_seasons
    Season.where(status: %w[upcoming active])
      .includes(:sport).joins(:sport)
      .where(
        "seasons.status = 'active' OR seasons.id IN (" \
        "SELECT DISTINCT ON (sport_id) s.id FROM seasons s " \
        "WHERE s.status = 'upcoming' ORDER BY s.sport_id, s.starts_on ASC" \
        ")"
      )
      .order(
        Arel.sql("CASE WHEN seasons.status = 'upcoming' THEN 0 ELSE 1 END"),
        Arel.sql("CASE WHEN seasons.status = 'upcoming' THEN seasons.starts_on END ASC"),
        Arel.sql("CASE WHEN seasons.status = 'active' THEN seasons.starts_on END DESC"),
        "sports.name"
      )
  end
  helper_method :selectable_seasons

  def chosen_season
    id = params.dig(:league, :season_id).presence
    return selectable_seasons.find_by(id: id) if id
    default_season
  end

  # Fallback when no season was chosen on the form (e.g. first render).
  # Prefer the soonest upcoming season, falling back to the most-recently-started active.
  def default_season
    selectable_seasons.where(status: "upcoming").first || selectable_seasons.first
  end

  def league_params
    params.require(:league).permit(:name, :private)
  end

  def render_no_season
    render plain: "No upcoming or active seasons are seeded. Run bin/rails db:seed.", status: :service_unavailable
  end

  def build_directory_query
    return nil unless @league_season
    Leagues::DirectoryQuery.from_request(
      league_season: @league_season,
      params: params,
      user: current_user
    )
  end

  def invite_verified_for?(league_season)
    return false unless league_season
    session[:verified_invites].is_a?(Hash) &&
      session[:verified_invites][league_season.id.to_s] == true
  end

  def mark_invite_verified(league_season)
    session[:verified_invites] ||= {}
    session[:verified_invites][league_season.id.to_s] = true
  end

  # When a verified invitee lands on a league with exactly one unclaimed seat
  # and isn't already a participant, skip the "Are you {name}?" picker and
  # claim it for them. Returns the claimed Participant, or nil if no claim
  # was performed (already in, multiple open seats, or none).
  def auto_claim_lone_seat(league_season)
    return nil if current_participant_for(@league).present?
    open_seats = league_season.participants.where(joined_at: nil).to_a
    return nil unless open_seats.size == 1
    seat = open_seats.first
    seat.update!(joined_at: Time.current, user: current_user)
    participant_claims.add(seat.claim_token)
    Drafts::StartIfReady.call(league_season: league_season)
    seat
  end
end
