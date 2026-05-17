# frozen_string_literal: true

class Views::Drafts::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::TurboStreamFrom
  include Components::Helpers::CurrentUser
  include Views::Components::TeamDirectoryHelpers

  DRAFT_COLUMNS = 6

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
        render_header
        render_draft_section
      end
    end
  end

  private

  def render_header
    div(class: "flex items-start justify-between gap-4") do
      div do
        h1(class: "text-2xl font-bold") { "#{@league.name} — Draft" }
        if league_landing_renders?
          a(href: league_path(@league), class: "text-sm link link-hover") { "← Back to league" }
        end
      end
      div(class: "flex items-center gap-2") do
        if @current_participant&.is_owner?
          a(href: edit_league_path(@league), class: "btn btn-ghost btn-sm") { "Edit league" }
        end
        if @current_participant&.is_owner? && @league_season.draft_picks.none?
          a(href: edit_league_draft_path(@league), class: "btn btn-ghost btn-sm") { "Draft settings" }
        end
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

  def render_draft_section
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        case @league_season.status
        when "draft_pending"
          render_pending_notice
        when "drafting"
          render_drafting_state
        else
          render_completed_state
        end
      end
    end
  end

  # When the final pick lands (manual or autopick), the broadcast refresh
  # morphs this page in place. Show a clear "done" state with a CTA to
  # standings rather than a redirect — redirects across morphs leave the
  # previous clock UI stuck on screen.
  def render_completed_state
    div(class: "space-y-3") do
      h2(class: "card-title") { "Draft complete" }
      p(class: "text-base-content/70") { "All #{@league_season.total_picks} picks are in." }
      div(class: "card-actions") do
        a(href: league_path(@league), class: "btn btn-primary") { "View standings →" }
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
    render_team_directory(on_the_clock)
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
        time(datetime: starts_at.iso8601,
          data_controller: "local-time",
          class: "font-medium") {
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
    # Stable id so Turbo morphing matches this element across refreshes
    # and reliably propagates the updated deadline value to Stimulus.
    # Without an id, morphdom can fall back to positional matching, which
    # in some cases left the autopick clock stuck on "auto-picking…".
    div(
      id: "draft-clock",
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
    @directory_query ||= Leagues::DirectoryQuery.new(league_season: @league_season, params: {})
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
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-10 bg-base-100")
            render Views::Components::SortableHeader.new(query: query, column: "name", label: "Team", path: league_draft_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "rank", label: "Rank", path: league_draft_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "division", label: "Conf / Div", path: league_draft_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "pick", label: "Pick", path: league_draft_path(@league))
            th(class: "text-right bg-base-100")
          end
        end
        if rows.empty?
          tbody { render_empty_row(DRAFT_COLUMNS) }
        else
          tbody do
            rows.each { |row| render_draft_row(query, row, on_the_clock) }
          end
        end
      end
    end
  end

  def render_draft_row(query, row, on_the_clock)
    team = row.team
    pick = row.pick
    tr do
      th { render_team_swatch(team) }
      td do
        div(class: "flex flex-col") do
          span(class: "font-medium") { team.name }
          span(class: "text-xs opacity-60") { team.abbreviation }
        end
      end
      td(class: "font-mono text-sm") { team.default_pick_rank ? team.default_pick_rank.to_s : "—" }
      td(class: "text-sm whitespace-nowrap") { division_label(team) || "—" }
      td(class: "text-sm whitespace-nowrap") { render_directory_pick_cell(pick) }
      th(class: "text-right") { render_directory_action_cell(query, row.season_team, pick, on_the_clock) }
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
