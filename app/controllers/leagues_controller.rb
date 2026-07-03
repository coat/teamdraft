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
      result = attempt_invite(params[:invite])
      return redirect_after_claim(result) if result.verified?
      flash.now[:alert] = "That invite code didn't match."
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
      invite_verified: invite_verifications.verified?(@league_season),
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
    unless invite_verifications.verified?(league_season)
      redirect_to league_path(@league), alert: "Enter the league's invite code to claim a seat."
      return
    end

    seat = league_season.participants.find(params[:seat_id])
    if seat.joined_at.present? || current_participant_for(@league).present?
      redirect_to league_path(@league), alert: "That seat is already claimed."
      return
    end

    Invites::ClaimSeat.call(seat: seat, user: current_user, participant_claims: participant_claims)
    redirect_to league_path(@league), notice: "Welcome, #{seat.display_name}."
  end

  def verify_invite
    @league_season = @league.current_league_season
    result = attempt_invite(params[:code])
    return redirect_after_claim(result) if result.verified?
    redirect_to league_path(@league), alert: "That invite code didn't match."
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

  def selectable_seasons
    @selectable_seasons ||= Seasons::Selectable.call
  end

  def chosen_season
    id = params.dig(:league, :season_id).presence
    return selectable_seasons.find_by(id: id) if id
    default_season
  end

  def default_season
    Seasons::Selectable.default
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

  def invite_verifications
    @invite_verifications ||= Invites::Verifications.new(session)
  end

  def attempt_invite(code)
    Invites::Claim.call(
      league_season: @league_season,
      code: code,
      user: current_user,
      current_participant: current_participant_for(@league),
      participant_claims: participant_claims,
      verifications: invite_verifications
    )
  end

  def redirect_after_claim(result)
    notice = result.auto_claimed? ? "Welcome, #{result.claimed_seat.display_name}." : nil
    redirect_to league_path(@league), notice: notice
  end
end
