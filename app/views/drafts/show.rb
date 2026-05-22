# frozen_string_literal: true

class Views::Drafts::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::TurboStreamFrom
  include Components::Helpers::CurrentUser
  include Views::Components::TeamDirectoryHelpers

  DRAFT_COLUMNS = 6
  DRAFT_COLUMNS_WITH_POINTS = 7

  def initialize(league:, league_season:, current_participant:, directory_query: nil)
    @league = league
    @league_season = league_season
    @current_participant = current_participant
    @directory_query = directory_query
  end

  def view_template
    render Views::Layouts::Application.new(title: "Draft — #{@league.name}") do
      turbo_stream_from @league
      main(class: "py-6 space-y-4") do
        render_breadcrumbs
        render_header
        render_draft_section
      end
    end
  end

  private

  # Only show the breadcrumb when the league page actually renders for
  # this viewer. While drafting with both seats claimed, /leagues/:id
  # redirects right back to the draft, which would make the link a loop.
  def render_breadcrumbs
    return unless league_landing_renders?
    render Views::Components::Breadcrumbs.new(trail: [
      [@league.name, league_path(@league)],
      ["Draft", nil]
    ])
  end

  def render_header
    div(class: "flex items-start justify-between gap-4") do
      h1(class: "text-2xl font-bold") { "#{@league.name} — Draft" }
      if @current_participant&.is_owner? && @league_season.draft_picks.none?
        a(href: edit_league_draft_path(@league), class: "btn btn-ghost btn-sm") { "Draft settings" }
      end
    end
  end

  # Would /leagues/:id actually render content, or does the landing-page
  # redirect bounce a claimed viewer right back here? Mirrors the
  # redirect condition in LeaguesController#show.
  def league_landing_renders?
    return true unless @league_season.status == "drafting"
    return true if @league_season.participants.where(joined_at: nil).any?
    @current_participant.nil?
  end

  # The sticky draft-clock bar lives OUTSIDE the card on purpose. daisyUI's
  # .card has overflow:clip and a corner radius, which clip the bar's top
  # edge and create a sticky scrolling context that jitters during scroll.
  # Keeping the bar as a sibling lets it pin cleanly to the viewport top.
  #
  # The drafting state also skips the card wrapper entirely so the team
  # directory (and the rankings tab embedded inside it) gets the full
  # mobile width instead of being squeezed by card-body padding. The
  # pending and completed states keep the card chrome since they show
  # short content that benefits from the visual container.
  def render_draft_section
    case @league_season.status
    when "draft_pending"
      render_pending_notice
      render_directory_with_optional_rankings(nil)
    when "drafting"
      on_the_clock = clock_participant
      viewer_on_clock = on_the_clock && @current_participant && @current_participant.id == on_the_clock.id
      render_draft_panel(on_the_clock, viewer_on_clock)
      render_directory_with_optional_rankings(on_the_clock)
    else
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body p-3 sm:p-6") { render_completed_state }
      end
    end
  end

  # When the final pick lands (manual or autopick), the broadcast refresh
  # morphs this page in place. Show a clear "done" state and let the
  # auto-visit controller hand off to the standings page once the morph
  # finishes — the picker themselves got redirected by the controller,
  # but other viewers (notably the league owner spectating someone
  # else's pick) only see the morph and would otherwise be stranded
  # here. A server-side redirect is avoided because morphing across a
  # redirect leaves the auto-pick clock UI on screen.
  def render_completed_state
    div(class: "space-y-3",
      data: {controller: "auto-visit", auto_visit_url_value: league_path(@league)}) do
      h2(class: "card-title") { "Draft complete" }
      p(class: "text-base-content/70") { "All #{@league_season.total_picks} picks are in. Taking you to the standings…" }
      div(class: "card-actions") do
        a(href: league_path(@league), class: "btn btn-primary inline-flex items-center gap-1") do
          plain "View standings"
          render Views::Components::Icon.new(:chevron_right)
        end
      end
    end
  end

  def render_directory_with_optional_rankings(on_the_clock)
    if current_user
      render_directory_and_rankings_tabs(on_the_clock)
    else
      # Anonymous viewers don't get the rankings tab, but the directory
      # still needs a bg-base-100 panel surface so daisyUI's table-zebra
      # (which alternates rows to base-200) has contrast against the
      # page background. Mirrors the signed-in tab-content treatment
      # without the tab strip.
      div(class: "mt-4 -mx-4 sm:mx-0 bg-base-100 sm:rounded-box sm:border sm:border-base-300 p-3 sm:p-4") do
        render_team_directory(on_the_clock)
      end
    end
  end

  def render_directory_and_rankings_tabs(on_the_clock)
    # -mx-4 sm:mx-0: break out of the layout's px-4 on phones so the tabs
    # go edge-to-edge. The tab-content keeps its own inner padding so
    # filters/tables aren't pressed against the panel border.
    div(class: "tabs tabs-lift mt-4 -mx-4 sm:mx-0") do
      input(type: "radio", name: "draft_view_tabs", class: "tab",
        aria_label: "Available teams", checked: true)
      div(class: "tab-content bg-base-100 border-base-300 p-3 sm:p-4") do
        render_team_directory(on_the_clock)
      end
      input(type: "radio", name: "draft_view_tabs", class: "tab",
        aria_label: "My rankings")
      # loading="lazy": defer the rankings fetch until the tab is actually
      # selected. An eager src= here mutates the DOM while the page is
      # still settling, which competes with the sticky draft-clock bar's
      # initial layout pass and produces a few-pixel scroll jitter on
      # owner views (the only role that sees this tab).
      div(class: "tab-content bg-base-100 border-base-300 p-3 sm:p-4") do
        turbo_frame_tag "user_rankings",
          src: sport_rankings_path(@league_season.season.sport.key),
          loading: "lazy",
          class: "block"
      end
    end
  end

  def render_draft_panel(on_the_clock, viewer_on_clock)
    has_clock = @league_season.draft_mode == "live" && @league_season.pick_clock_seconds.present?
    deadline = has_clock ? clock_deadline : nil
    autopick = (deadline ? next_autopick_team : nil)

    base = "sticky top-0 z-20 -mx-4 sm:mx-0 sm:rounded-box border shadow-sm px-4 py-3"
    state = if viewer_on_clock
      "border-success bg-success text-success-content"
    else
      "border-base-300 bg-base-100/95 backdrop-blur supports-[backdrop-filter]:bg-base-100/80"
    end

    attrs = {class: [base, state].reject(&:empty?).join(" ")}
    if deadline
      # Stable id so Turbo morphing matches this element across refreshes
      # and reliably propagates the updated deadline value to Stimulus.
      attrs[:id] = "draft-clock"
      attrs[:data_controller] = "draft-clock"
      attrs[:data_draft_clock_deadline_value] = deadline.iso8601
      attrs[:data_draft_clock_mode_value] = "seconds"
    end

    div(**attrs) do
      div(class: "flex items-center justify-between gap-3") do
        div(class: "flex flex-col min-w-0") do
          if on_the_clock
            if viewer_on_clock
              span(class: "sm:hidden font-bold") { "Your pick!" }
              span(class: "hidden sm:inline text-lg font-bold uppercase tracking-wide leading-tight") { "You're on the clock!" }
            else
              span(class: "truncate") do
                plain "On the clock: "
                strong { on_the_clock.display_name }
              end
            end
          end
          span(class: "text-xs opacity-70") do
            plain "Pick "
            strong { "##{@league_season.current_pick_number}" }
            plain " of #{@league_season.total_picks}"
          end
        end
        render_clock_box(@league_season.pick_clock_seconds) if deadline
      end
      if autopick
        div(class: "hidden mt-2 text-sm text-base-content/70", data_draft_clock_target: "autopick") do
          plain "Auto-pick if time expires: "
          strong { autopick.team.name }
        end
      end
    end
  end

  def render_clock_box(initial)
    div(class: "flex flex-col items-center px-3 py-1.5 bg-neutral text-neutral-content rounded-box shrink-0") do
      span(class: "countdown font-mono text-3xl sm:text-4xl font-bold leading-none") do
        span(
          class: "inline-block min-w-[3ch] text-center tabular-nums",
          style: "--value:#{initial};",
          data_draft_clock_target: "display",
          aria_live: "polite",
          aria_label: initial.to_s
        ) { initial.to_s }
      end
    end
  end

  def render_pending_notice
    unclaimed = @league_season.participants.where(joined_at: nil).any?
    scheduled = @league_season.draft_scheduled_at.present? && @league_season.draft_scheduled_at > Time.current
    if unclaimed
      p(class: "text-base-content/70") { "Waiting for the other player to claim their seat." }
    end
    if scheduled
      render_scheduled_notice
    elsif !unclaimed
      p(class: "text-base-content/70") { "Draft is starting…" }
    end
  end

  def render_scheduled_notice
    starts_at = @league_season.draft_scheduled_at
    remaining = [(starts_at - Time.current).round, 0].max
    div(
      class: "flex flex-col items-center gap-3 py-4",
      data_controller: "draft-clock",
      data_draft_clock_deadline_value: starts_at.iso8601,
      data_draft_clock_mode_value: "boxes",
      data_draft_clock_expired_text_value: "starting…"
    ) do
      span(class: "text-base-content/70") { "Draft starts in" }
      div(class: "grid grid-flow-col gap-3 sm:gap-5 text-center auto-cols-max") do
        render_countdown_box("days",  "days",  remaining / 86400)
        render_countdown_box("hours", "hours", (remaining % 86400) / 3600)
        render_countdown_box("min",   "min",   (remaining % 3600) / 60)
        render_countdown_box("sec",   "sec",   remaining % 60)
      end
    end
  end

  def render_countdown_box(target, label, initial)
    div(class: "flex flex-col p-2 bg-neutral rounded-box text-neutral-content") do
      span(class: "countdown font-mono text-4xl") do
        span(
          class: "inline-block min-w-[2ch] text-center tabular-nums",
          style: "--value:#{initial};",
          data_draft_clock_target: target,
          aria_live: "polite",
          aria_label: initial.to_s
        ) { initial.to_s }
      end
      plain label
    end
  end

  def can_pick?(on_the_clock)
    return false unless @current_participant
    return false unless @league_season.status == "drafting"
    case @league_season.draft_mode
    when "manual" then @current_participant.is_owner?
    when "live" then on_the_clock && @current_participant.id == on_the_clock.id
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

  def render_team_directory(on_the_clock)
    query = directory_query
    rows = query.rows
    divisions = all_division_labels

    turbo_frame_tag "team_directory", class: "space-y-3 mt-4 block" do
      render_directory_filters(query, divisions)
      render_draft_table(query, rows, on_the_clock)
    end
  end

  def directory_query
    @directory_query ||= Leagues::DirectoryQuery.new(league_season: @league_season, params: {}, user: current_user)
  end

  def render_directory_filters(query, divisions)
    form(action: league_draft_path(@league), method: "get", class: "flex flex-wrap items-end gap-3",
      data: {controller: "auto-submit", turbo_action: "advance"}) do
      div(class: "space-y-1") do
        label(class: "label label-text text-xs uppercase tracking-wide opacity-60",
          for: "team-directory-status") { "Status" }
        select(
          id: "team-directory-status",
          name: "status",
          class: "select select-bordered select-sm",
          data: {action: "change->auto-submit#submit"}
        ) do
          status_option("", "All teams", query.status)
          status_option("available", "Available", query.status) if @league_season.status == "drafting"
          @league_season.participants.each do |p|
            status_option(query.status_token_for(p), "Picked by #{p.display_name}", query.status)
          end
        end
      end
      if divisions.any?
        div(class: "space-y-1") do
          label(class: "label label-text text-xs uppercase tracking-wide opacity-60",
            for: "team-directory-division") { "Division" }
          select(
            id: "team-directory-division",
            name: "division",
            class: "select select-bordered select-sm",
            data: {action: "change->auto-submit#submit"}
          ) do
            division_option("", "All divisions", query.division)
            divisions.each { |d| division_option(d, d, query.division) }
          end
        end
      end
      input(type: "hidden", name: "sort", value: query.sort_column)
      input(type: "hidden", name: "dir", value: query.sort_dir)
    end
  end

  def render_draft_table(query, rows, on_the_clock)
    show_points = query.any_scoring_events?
    # The Pick column is meaningless under the "Available" filter — every
    # row would be blank — so collapse it in that case.
    show_pick = query.status != "available"
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-10 bg-base-100")
            render Views::Components::SortableHeader.new(query: query, column: "name", label: "Team", path: league_draft_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "rank", label: "Rank", path: league_draft_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "division", label: "Conf / Div", path: league_draft_path(@league), class_name: "hidden sm:table-cell")
            if show_pick
              render Views::Components::SortableHeader.new(query: query, column: "pick", label: "Pick", path: league_draft_path(@league))
            end
            if show_points
              render Views::Components::SortableHeader.new(query: query, column: "points", label: "Points", path: league_draft_path(@league))
            end
            th(class: "text-right bg-base-100")
          end
        end
        column_count = (show_points ? DRAFT_COLUMNS_WITH_POINTS : DRAFT_COLUMNS) - (show_pick ? 0 : 1)
        if rows.empty?
          tbody { render_empty_row(column_count) }
        else
          tbody do
            rows.each { |row| render_draft_row(query, row, on_the_clock, show_points, show_pick) }
          end
        end
      end
    end
  end

  def render_draft_row(query, row, on_the_clock, show_points, show_pick)
    team = row.team
    pick = row.pick
    tr do
      th { render_team_swatch(team) }
      td(class: "font-medium") { team.name }
      td(class: "font-mono text-sm") { render_rank_cell(row) }
      td(class: "text-sm whitespace-nowrap hidden sm:table-cell") { division_label(team) || "—" }
      td(class: "text-sm whitespace-nowrap") { render_directory_pick_cell(pick) } if show_pick
      td(class: "font-mono text-right") { row.points.to_s } if show_points
      th(class: "text-right") { render_directory_action_cell(query, row.season_team, pick, on_the_clock) }
    end
  end

  def render_rank_cell(row)
    if row.user_rank
      span(class: "font-semibold", title: "Your rank") { row.user_rank.to_s }
      span(class: "ml-1 opacity-50 inline-flex align-middle", title: "Your rank") do
        render Views::Components::Icon.new(:star, variant: :solid, class_name: "size-3")
      end
    elsif row.team.default_pick_rank
      plain row.team.default_pick_rank.to_s
    else
      plain "—"
    end
  end

  def render_directory_action_cell(query, season_team, pick, on_the_clock)
    return if pick
    return unless can_pick?(on_the_clock)
    # turbo-frame="_top" breaks out of the team_directory frame so the
    # post-pick redirect (which may flip to in_season and lose the frame)
    # is treated as a full page swap.
    button_to "Pick", league_draft_picks_path(@league, **query.to_url_params),
      method: :post,
      params: {season_team_id: season_team.id},
      form: {class: "inline", data: {turbo_frame: "_top"}},
      class: "btn btn-primary btn-sm"
  end
end
