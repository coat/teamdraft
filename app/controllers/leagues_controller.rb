# frozen_string_literal: true

class LeaguesController < ApplicationController
  before_action :load_league, only: [:show, :claim, :edit, :update]
  before_action :require_account_owner, only: [:edit, :update]

  def index
    participants = participants_for_visitor
    case participants.size
    when 0
      render Views::Pages::Home.new(league: new_league)
    when 1
      redirect_to league_path(participants.first.league)
    else
      render Views::Leagues::Index.new(participants: participants)
    end
  end

  def new
    render_new_form
  end

  def create
    season = default_season
    return render_no_season unless season

    league, owner = Leagues::Create.call(
      your_name: params.dig(:league, :your_name),
      opponent_name: params.dig(:league, :opponent_name),
      season:,
      draft_scheduled_at: params.dig(:league, :draft_scheduled_at).presence,
      draft_mode: params.dig(:league, :draft_mode).presence || "live",
      pick_clock_seconds: params.dig(:league, :pick_clock_seconds).presence,
      owner_user: current_user
    )
    participant_claims.add(owner.claim_token)
    redirect_to league_path(league), notice: "League created. Share this URL with your opponent."
  rescue ActiveRecord::RecordInvalid => e
    @league = e.record.is_a?(League) ? e.record : League.new
    @errors = e.record.errors.full_messages
    render Views::Leagues::New.new(league: @league, errors: @errors), status: :unprocessable_entity
  end

  def show
    render Views::Leagues::Show.new(
      league: @league,
      current_participant: current_participant_for(@league)
    )
  end

  def edit
    render Views::Leagues::Edit.new(league: @league)
  end

  def update
    new_slug = params.dig(:league, :slug_candidate).to_s.strip.presence
    new_name = params.dig(:league, :name).to_s.strip.presence
    @league.name = new_name if new_name
    @league.slug_candidate = new_slug if new_slug

    if @league.save
      redirect_to league_path(@league), notice: "League updated."
    else
      render Views::Leagues::Edit.new(league: @league),
        status: :unprocessable_entity
    end
  end

  def claim
    seat = @league.participants.find(params[:seat_id])
    if seat.joined_at.present? || current_participant_for(@league).present?
      redirect_to league_path(@league), alert: "That seat is already claimed."
      return
    end

    seat.update!(joined_at: Time.current, user: current_user)
    participant_claims.add(seat.claim_token)
    Drafts::StartIfReady.call(league: @league)
    redirect_to league_path(@league), notice: "Welcome, #{seat.display_name}."
  end

  private

  def render_new_form
    render Views::Leagues::New.new(league: new_league)
  end

  def new_league
    League.new(draft_scheduled_at: 5.minutes.from_now, draft_mode: "manual")
  end

  def participants_for_visitor
    user_ids = current_user ? Participant.where(user_id: current_user.id).pluck(:id) : []
    token_ids = Participant.where(claim_token: participant_claims.tokens).pluck(:id)
    Participant.where(id: (user_ids + token_ids).uniq).includes(league: :season)
  end

  def load_league
    @league = League.friendly.find(params[:id])
    return unless action_name == "show"
    return if request.path == league_path(@league)
    redirect_to league_path(@league), status: :moved_permanently
  end

  def require_account_owner
    participant = current_participant_for(@league)
    unless participant&.is_owner? && participant.user_id.present?
      redirect_to league_path(@league),
        alert: "Sign in as the league owner to rename this league."
    end
  end

  def default_season
    Season.where(status: "active").joins(:sport).find_by(sports: {key: "nfl"}) ||
      Season.joins(:sport).where(sports: {key: "nfl"}).order(year: :desc).first
  end

  def render_no_season
    render plain: "No active NFL season seeded. Run bin/rails db:seed.", status: :service_unavailable
  end
end
