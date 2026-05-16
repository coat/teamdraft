# frozen_string_literal: true

class Views::Leagues::Show < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboStreamFrom
  include Components::Helpers::CurrentUser

  def initialize(league:, league_season:, current_participant:)
    @league = league
    @league_season = league_season
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
        post_draft_with_picks = viewable? && draft_finished? && @league_season.draft_picks.any?
        render_leaderboard(standings_rows) if post_draft_with_picks
        render_participants unless post_draft_with_picks
        if viewable? && draft_finished?
          render_standings(standings_rows) if @league_season.draft_picks.any?
        elsif viewable?
          render_draft_section
        end
      end
    end
  end

  private

  def claimed? = @current_participant.present?

  def draft_finished? = @league_season&.draft_finished?

  def viewable?
    return true if claimed?
    return false if @league.private?
    @league_season.participants.where(joined_at: nil).none?
  end

  def unclaimed_seat = @league_season.participants.find_by(joined_at: nil)

  def needs_claim_prompt?
    !claimed? && unclaimed_seat.present?
  end

  def needs_account_upsell?
    claimed? && @current_participant.user_id.nil? && current_user.nil?
  end

  def render_header
    div(class: "flex items-start justify-between gap-4") do
      div do
        h1(class: "text-3xl font-bold") { @league.name }
        render_season_chip
      end
      div(class: "flex items-center gap-2") do
        if @league.league_seasons.count > 1
          a(href: history_league_path(@league), class: "btn btn-ghost btn-sm") { "History" }
        end
        if @current_participant&.is_owner? && @current_participant.user_id.present?
          a(href: edit_league_path(@league), class: "btn btn-ghost btn-sm") { "Edit league" }
        end
      end
    end
  end

  def render_season_chip
    return unless @league_season&.season
    span(class: "badge badge-ghost badge-sm mt-1") { @league_season.season.label }
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
          @league_season.participants.each do |p|
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

        case @league_season.status
        when "in_season", "completed"
          p { "Draft complete (#{@league_season.draft_picks.count} of #{@league_season.total_picks} picks)." }
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
      span(class: "badge badge-lg") { "Pick ##{@league_season.current_pick_number} of #{@league_season.total_picks}" }
      if on_the_clock
        span do
          plain "On the clock: "
          strong(class: "text-primary") { on_the_clock.display_name }
        end
      end
    end
    render_clock if @league_season.draft_mode == "live" && @league_season.pick_clock_seconds.present?
    render_pick_form if can_pick?(on_the_clock)
    render_pick_history if @league_season.draft_picks.any?
  end

  def render_pending_notice
    if @league_season.participants.where(joined_at: nil).any?
      p(class: "text-base-content/70") { "Waiting for the other player to claim their seat." }
    elsif @league_season.draft_scheduled_at.present? && @league_season.draft_scheduled_at > Time.current
      render_scheduled_notice
    else
      p(class: "text-base-content/70") { "Draft is starting…" }
    end
  end

  def render_scheduled_notice
    starts_at = @league_season.draft_scheduled_at
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
    case @league_season.draft_mode
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
      span(class: "font-mono text-lg", data_draft_clock_target: "display") { "#{@league_season.pick_clock_seconds}s" }
      if autopick
        span(class: "hidden text-sm", data_draft_clock_target: "autopick") do
          plain "Auto-pick if time expires: "
          strong { "#{autopick.team.name} (#{autopick.team.abbreviation})" }
        end
      end
    end
  end

  def next_autopick_team
    drafted = @league_season.draft_picks.pluck(:season_team_id)
    @league_season.season.season_teams
      .joins(:team)
      .where.not(season_teams: {id: drafted})
      .order(Arel.sql("teams.default_pick_rank NULLS LAST, teams.name ASC"))
      .first
  end

  def clock_deadline
    last_pick_at = @league_season.draft_picks.maximum(:picked_at)
    started_at = @league_season.draft_started_at || last_pick_at
    return nil if started_at.nil? && last_pick_at.nil?
    base = last_pick_at || started_at
    base + @league_season.pick_clock_seconds.seconds
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

  def available_season_teams
    drafted = @league_season.draft_picks.pluck(:season_team_id)
    @league_season.season.season_teams.includes(:team).where.not(id: drafted)
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
        @league_season.draft_picks.includes(:participant, season_team: :team).each do |pick|
          li(class: "flex items-baseline gap-2 text-sm") do
            span(class: "badge badge-ghost font-mono") { "##{pick.pick_number}" }
            strong { pick.participant.display_name }
            span(class: "opacity-60") { "→" }
            span { "#{pick.team.name} (#{pick.team.abbreviation})" }
            span(class: "badge badge-sm badge-warning badge-outline") { "auto" } if pick.autopicked
          end
        end
      end
    end
  end

  def standings_rows
    @standings_rows ||= Standings::Calculate.call(league_season: @league_season)
  end

  def render_leaderboard(rows)
    leader_points = rows.first.total_points
    has_leader = leader_points.positive?
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        div(class: "flex flex-wrap gap-3") do
          rows.each_with_index do |row, idx|
            leading = has_leader && row.total_points == leader_points
            render_leaderboard_pill(row, idx + 1, leading)
          end
        end
      end
    end
  end

  def render_leaderboard_pill(row, rank, leading)
    container = "flex items-center gap-2 px-3 py-2 rounded-lg border #{leading ? "border-warning bg-warning/10" : "border-base-300"}"
    div(class: container) do
      span(class: "badge badge-sm #{leading ? "badge-warning" : "badge-neutral"}") { "##{rank}" }
      span(class: "font-medium") { row.participant.display_name }
      span(class: "badge badge-primary badge-outline badge-sm") { "you" } if row.participant == @current_participant
      span(class: "badge badge-secondary badge-outline badge-sm") { "owner" } if row.participant.is_owner?
      span(class: "font-bold tabular-nums") { row.total_points.to_s }
      span(class: "text-xs opacity-60") { "pts" }
    end
  end

  def render_standings(rows)
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
      div(class: "flex items-baseline justify-between mb-2 gap-2") do
        div(class: "flex items-baseline gap-2 flex-wrap") do
          h3(class: "font-medium") { row.participant.display_name }
          span(class: "badge badge-primary badge-outline badge-sm") { "you" } if row.participant == @current_participant
          span(class: "badge badge-secondary badge-outline badge-sm") { "owner" } if row.participant.is_owner?
        end
        span(class: "badge badge-primary badge-lg") { "#{row.total_points} pts" }
      end
      if row.teams.empty?
        p(class: "text-sm text-base-content/60") { "No teams drafted yet." }
      else
        div(class: "overflow-x-auto") do
          table(class: "table table-sm") do
            thead do
              tr do
                th(class: "w-8")
                th { "Team" }
                th { "Pick" }
                th(class: "text-right") { "Points" }
              end
            end
            row.teams.each { |line| render_team_lines(line) }
          end
        end
      end
    end
  end

  EVENT_LABELS = {
    "regular_win" => "Regular-season wins",
    "playoff_appearance" => "Playoff appearance",
    "divisional_appearance" => "Divisional round",
    "conference_appearance" => "Conference championship",
    "championship_appearance" => "Super Bowl appearance",
    "championship_win" => "Super Bowl win"
  }.freeze

  def render_team_lines(line)
    panel_id = "breakdown-#{line.season_team.id}"
    tbody(data: {controller: "disclosure"}) do
      tr do
        td do
          button(type: "button", class: "btn btn-ghost btn-xs",
            aria_expanded: "false", aria_controls: panel_id,
            data: {action: "click->disclosure#toggle"}) do
            span(class: "inline-block transition-transform",
              data: {disclosure_target: "icon"}) { "▸" }
          end
        end
        td do
          a(href: season_team_path(@league_season.season, slug: line.team.slug), class: "link link-hover") { line.team.name }
        end
        td(class: "font-mono opacity-60") do
          plain "##{line.pick_number}"
          if line.autopicked
            plain " "
            span(class: "badge badge-xs badge-warning badge-outline") { "auto" }
          end
        end
        td(class: "text-right") { line.points.to_s }
      end
      tr(id: panel_id, class: "hidden", data: {disclosure_target: "panel"}) do
        td(colspan: "4", class: "bg-base-200/50") do
          render_breakdown(line)
        end
      end
    end
  end

  def render_breakdown(line)
    nonzero = line.events.reject { |_, points| points.zero? }
    if nonzero.empty?
      p(class: "text-sm text-base-content/60 py-2") { "No scoring yet." }
    else
      dl(class: "grid grid-cols-2 gap-x-4 gap-y-1 text-sm py-2") do
        EVENT_LABELS.each do |event_type, label|
          points = nonzero[event_type]
          next unless points
          dt(class: "opacity-70") { label }
          dd(class: "text-right font-mono") { points.to_s }
        end
      end
    end
  end
end
