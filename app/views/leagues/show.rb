# frozen_string_literal: true

class Views::Leagues::Show < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboStreamFrom
  include Components::Helpers::CurrentUser

  def initialize(league:, current_participant:)
    @league = league
    @current_participant = current_participant
  end

  def view_template
    render Views::Layouts::Application.new(title: @league.name) do
      turbo_stream_from @league
      main(class: "py-6 space-y-4") do
        render_header
        render_share_card if unclaimed_seat.present?
        render_claim_prompt if needs_claim_prompt?
        render_account_upsell if needs_account_upsell?
        render_participants
        if viewable? && draft_finished?
          # Once the draft is over, standings (which already include each
          # pick's number) are the headline — pick history would just repeat.
          render_standings if @league.draft_picks.any?
        elsif viewable?
          render_draft_section
        end
      end
    end
  end

  private

  def claimed? = @current_participant.present?

  def draft_finished? = %w[in_season completed].include?(@league.status)

  def viewable?
    return true if claimed?
    return false if @league.private?
    @league.participants.where(joined_at: nil).none?
  end

  def unclaimed_seat = @league.participants.find_by(joined_at: nil)

  def needs_claim_prompt?
    !claimed? && unclaimed_seat.present?
  end

  def needs_account_upsell?
    claimed? && @current_participant.user_id.nil? && current_user.nil?
  end

  def render_header
    div(class: "flex items-start justify-between gap-4") do
      h1(class: "text-3xl font-bold") { @league.name }
      if @current_participant&.is_owner? && @current_participant.user_id.present?
        a(href: edit_league_path(@league), class: "btn btn-ghost btn-sm") { "Edit league" }
      end
    end
  end

  def render_share_card
    seat = unclaimed_seat
    div(
      class: "card bg-primary/10 border border-primary/30 shadow-sm",
      data_controller: "clipboard"
    ) do
      div(class: "card-body gap-3") do
        div do
          h2(class: "card-title text-base") { "Share this link with #{seat.display_name}" }
          p(class: "text-sm text-base-content/70") { "They'll claim seat ##{seat.draft_position} and the draft can begin." }
        end
        div(class: "join w-full") do
          input(
            type: "text",
            value: league_url(@league),
            readonly: true,
            class: "input input-bordered join-item flex-1 font-mono text-sm",
            data_clipboard_target: "source",
            data_action: "click->clipboard#select"
          )
          button(
            type: "button",
            class: "btn btn-primary join-item",
            data_action: "click->clipboard#copy"
          ) do
            span(data_clipboard_target: "label") { "Copy link" }
          end
        end
      end
    end
  end

  def render_account_upsell
    div(class: "alert alert-info") do
      p do
        plain "Save your seat across devices — "
        a(href: new_registration_path, class: "link link-primary font-medium") { "create an account" }
        plain "."
      end
    end
  end

  def render_claim_prompt
    seat = unclaimed_seat
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Are you #{seat.display_name}?" }
        p { "Claim this seat to start drafting." }
        div(class: "card-actions justify-end mt-2") do
          button_to "Yes, that's me", claim_league_path(@league, seat_id: seat.id),
            method: :post, class: "btn btn-primary"
        end
      end
    end
  end

  def render_participants
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Participants" }
        ol(class: "space-y-2 mt-2") do
          @league.participants.each do |p|
            li(class: "flex items-center gap-2") do
              span(class: "badge badge-neutral") { "#" + p.draft_position.to_s }
              strong { p.display_name }
              span(class: "badge badge-primary badge-outline") { "you" } if p == @current_participant
              span(class: "badge badge-secondary badge-outline") { "owner" } if p.is_owner?
              span(class: "text-sm text-base-content/60") { "(unclaimed)" } if p.joined_at.nil?
            end
          end
        end
      end
    end
  end

  def render_draft_section
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Draft" }

        case @league.status
        when "in_season", "completed"
          p { "Draft complete (#{@league.draft_picks.count} of #{@league.total_picks} picks)." }
          render_pick_history
        when "draft_pending"
          render_pending_notice
        else
          render_drafting_state
        end
      end
    end
  end

  def render_drafting_state
    on_the_clock = clock_participant
    div(class: "flex items-center gap-3 mb-3") do
      span(class: "badge badge-lg") { "Pick ##{@league.current_pick_number} of #{@league.total_picks}" }
      if on_the_clock
        span do
          plain "On the clock: "
          strong(class: "text-primary") { on_the_clock.display_name }
        end
      end
    end
    render_clock if @league.draft_mode == "live" && @league.pick_clock_seconds.present?
    render_pick_form if can_pick?(on_the_clock)
    render_pick_history if @league.draft_picks.any?
  end

  def render_pending_notice
    if @league.participants.where(joined_at: nil).any?
      p(class: "text-base-content/70") { "Waiting for the other player to claim their seat." }
    elsif @league.draft_scheduled_at.present? && @league.draft_scheduled_at > Time.current
      render_scheduled_notice
    else
      p(class: "text-base-content/70") { "Draft is starting…" }
    end
  end

  def render_scheduled_notice
    starts_at = @league.draft_scheduled_at
    if starts_at <= 5.minutes.from_now
      div(
        class: "alert alert-info",
        data_controller: "draft-clock",
        data_draft_clock_deadline_value: starts_at.iso8601,
        data_draft_clock_expired_text_value: "starting…"
      ) do
        span { "Draft starts in " }
        span(class: "font-mono text-lg font-medium", data_draft_clock_target: "display") {
          "#{(starts_at - Time.current).round}s"
        }
      end
    else
      p do
        plain "Draft starts "
        time(datetime: starts_at.iso8601, class: "font-medium") {
          starts_at.strftime("%a %b %-d at %-l:%M %p %Z")
        }
        plain "."
      end
    end
  end

  def can_pick?(on_the_clock)
    return false unless @current_participant
    case @league.draft_mode
    when "manual" then @current_participant.is_owner?
    when "live" then on_the_clock && @current_participant.id == on_the_clock.id
    end
  end

  def render_clock
    deadline = clock_deadline
    return if deadline.nil?
    autopick = next_autopick_team
    div(
      class: "alert mb-3 flex-wrap gap-2",
      data_controller: "draft-clock",
      data_draft_clock_deadline_value: deadline.iso8601
    ) do
      span(class: "font-mono text-lg", data_draft_clock_target: "display") { "#{@league.pick_clock_seconds}s" }
      if autopick
        span(class: "hidden text-sm", data_draft_clock_target: "autopick") do
          plain "Auto-pick if time expires: "
          strong { "#{autopick.team.name} (#{autopick.team.abbreviation})" }
        end
      end
    end
  end

  def next_autopick_team
    drafted = @league.draft_picks.pluck(:season_team_id)
    @league.season.season_teams
      .joins(:team)
      .where.not(season_teams: {id: drafted})
      .order(Arel.sql("teams.default_pick_rank NULLS LAST, teams.name ASC"))
      .first
  end

  def clock_deadline
    last_pick_at = @league.draft_picks.maximum(:picked_at)
    started_at = @league.draft_started_at || last_pick_at
    return nil if started_at.nil? && last_pick_at.nil?
    base = last_pick_at || started_at
    base + @league.pick_clock_seconds.seconds
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

  def available_season_teams
    drafted = @league.draft_picks.pluck(:season_team_id)
    @league.season.season_teams.includes(:team).where.not(id: drafted)
  end

  def render_pick_form
    form_with(url: league_draft_picks_path(@league), method: :post, class: "space-y-3") do |form|
      div(class: "space-y-1") do
        form.label :season_team_id, "Pick a team", class: "label label-text font-medium"
        form.select :season_team_id,
          available_season_teams.map { |st| ["#{st.team.name} (#{st.team.abbreviation})", st.id] },
          {include_blank: "— choose —"},
          required: true, class: "select w-full"
      end
      form.submit "Record pick", class: "btn btn-primary"
    end
  end

  def render_pick_history
    div(class: "mt-4") do
      h3(class: "font-medium mb-2") { "Picks" }
      ol(class: "space-y-1") do
        @league.draft_picks.includes(:participant, season_team: :team).each do |pick|
          li(class: "flex items-baseline gap-2 text-sm") do
            span(class: "badge badge-ghost font-mono") { "##{pick.pick_number}" }
            strong { pick.participant.display_name }
            span(class: "opacity-60") { "→" }
            span { "#{pick.team.name} (#{pick.team.abbreviation})" }
          end
        end
      end
    end
  end

  def render_standings
    rows = Standings::Calculate.call(league: @league)
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Standings" }
        div(class: "space-y-4") do
          rows.each { |row| render_standings_row(row) }
        end
      end
    end
  end

  def render_standings_row(row)
    div do
      div(class: "flex items-baseline justify-between mb-2") do
        h3(class: "font-medium") { row.participant.display_name }
        span(class: "badge badge-primary badge-lg") { "#{row.total_points} pts" }
      end
      if row.teams.empty?
        p(class: "text-sm text-base-content/60") { "No teams drafted yet." }
      else
        div(class: "overflow-x-auto") do
          table(class: "table table-sm") do
            thead do
              tr do
                th { "Team" }
                th { "Pick" }
                th(class: "text-right") { "Points" }
              end
            end
            tbody do
              row.teams.each do |line|
                tr do
                  td { line.team.name }
                  td(class: "font-mono opacity-60") { "##{line.pick_number}" }
                  td(class: "text-right") { line.points.to_s }
                end
              end
            end
          end
        end
      end
    end
  end
end
