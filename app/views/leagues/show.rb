# frozen_string_literal: true

class Views::Leagues::Show < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::TurboStreamFrom
  include Components::Helpers::CurrentUser

  def initialize(league:, league_season:, current_participant:, invite_verified: false, directory_query: nil)
    @league = league
    @league_season = league_season
    @current_participant = current_participant
    @invite_verified = invite_verified
    @directory_query = directory_query
  end

  def view_template
    render Views::Layouts::Application.new(title: @league.name) do
      turbo_stream_from @league
      main(class: "py-6 space-y-4") do
        render_header
        render_share_card if owner_view? && unclaimed_seat.present?
        render_invite_prompt if needs_invite_prompt?
        render_claim_prompt if needs_claim_prompt?
        render_account_upsell if needs_account_upsell?
        post_draft_with_picks = viewable? && draft_finished? && @league_season.draft_picks.any?
        render_leaderboard(standings_rows) if post_draft_with_picks
        render_participants unless post_draft_with_picks
        if viewable? && draft_finished?
          render_post_draft_directory if @league_season.draft_picks.any?
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

  def owner_view? = @current_participant&.is_owner?

  def needs_claim_prompt?
    !claimed? && unclaimed_seat.present? && @invite_verified
  end

  def needs_invite_prompt?
    !claimed? && !owner_view? && unclaimed_seat.present? && !@invite_verified
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
        if @current_participant&.is_owner?
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
    invite_url = league_url(@league, invite: @league_season.invite_code)
    div(class: "card bg-primary/10 border border-primary/30 shadow-sm") do
      div(class: "card-body gap-3") do
        div do
          h2(class: "card-title text-base") { "Invite #{seat.display_name}" }
          p(class: "text-sm text-base-content/70") do
            plain "Share the code so they can claim seat ##{seat.draft_position}. They'll enter it after visiting the league page."
          end
        end
        render_copyable_row(label: "Invite code", value: @league_season.invite_code, button_label: "Copy code")
        render_copyable_row(label: "Or share a one-click link", value: invite_url, button_label: "Copy link")
      end
    end
  end

  def render_copyable_row(label:, value:, button_label:)
    div(class: "space-y-1", data_controller: "clipboard") do
      span(class: "text-xs uppercase tracking-wide opacity-60") { label }
      div(class: "join w-full") do
        input(
          type: "text",
          value: value,
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
          span(data_clipboard_target: "label") { button_label }
        end
      end
    end
  end

  def render_invite_prompt
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Have an invite code?" }
        p(class: "text-sm text-base-content/70") { "The league owner can share a short code with you. Enter it to claim your seat." }
        form_with(url: verify_invite_league_path(@league), method: :post, class: "join w-full mt-2") do |form|
          form.text_field :code, required: true, autocomplete: "off",
            placeholder: "e.g. frosty-otter-422",
            class: "input input-bordered join-item flex-1 font-mono"
          form.submit "Continue", class: "btn btn-primary join-item"
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
          render_team_directory(nil)
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
        # The Stimulus `local-time` controller swaps this to the visitor's
        # local timezone; fall back to server-time strftime if JS is off.
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

  def render_team_directory(on_the_clock)
    query = directory_query
    rows = query.rows
    divisions = all_division_labels

    # The whole picker is one Turbo frame. Sort-header links + the filter
    # form swap just this frame; clock countdown and the rest of the page
    # stay untouched. broadcasts_refreshes_to refreshes the current URL,
    # which already carries the viewer's sort/filter, so each viewer keeps
    # their chosen view across other people's picks.
    turbo_frame_tag "team_directory", class: "space-y-3 mt-4 block" do
      render_directory_filters(query, divisions)
      render_directory_table(query, rows, on_the_clock)
    end
  end

  def render_post_draft_directory
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Standings" }
        render_team_directory(nil)
      end
    end
  end

  def directory_query
    @directory_query ||= Leagues::DirectoryQuery.new(league_season: @league_season, params: {})
  end

  def all_division_labels
    @league_season.season.season_teams.includes(:team).map { |st| division_label(st.team) }.compact.uniq.sort
  end

  def render_directory_filters(query, divisions)
    form(action: league_path(@league), method: "get", class: "flex flex-wrap items-end gap-3",
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
      # Preserve current sort across filter submits.
      input(type: "hidden", name: "sort", value: query.sort_column)
      input(type: "hidden", name: "dir", value: query.sort_dir)
    end
  end

  def status_option(value, label_text, current)
    option(value: value, selected: (value == current)) { label_text }
  end

  def division_option(value, label_text, current)
    option(value: value, selected: (value == current)) { label_text }
  end

  # Two phases, one filter card + Turbo frame. Each phase owns its column
  # set since draft and standings answer different questions: drafting is
  # "what can I pick next?" (rank matters, points don't exist), standings
  # is "how did each pick perform?" (points + breakdown matter, rank is
  # noise once the pick is locked in).
  def render_directory_table(query, rows, on_the_clock)
    if draft_finished?
      render_standings_table(query, rows)
    else
      render_draft_table(query, rows, on_the_clock)
    end
  end

  DRAFT_COLUMNS = 6
  STANDINGS_COLUMNS = 6

  # daisyUI's `table-pin-cols` pins the first and last <th> in every row,
  # so the cell types matter: logo + action are <th>, the middle cells
  # remain <td>. The table-zebra background carries through to the
  # pinned cells so scrolled content doesn't bleed underneath.
  def render_draft_table(query, rows, on_the_clock)
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-10 bg-base-100")
            render Views::Components::SortableHeader.new(query: query, column: "name", label: "Team", path: league_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "rank", label: "Rank", path: league_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "division", label: "Conf / Div", path: league_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "pick", label: "Pick", path: league_path(@league))
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

  def render_standings_table(query, rows)
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-8 bg-base-100")
            th(class: "w-10")
            render Views::Components::SortableHeader.new(query: query, column: "name", label: "Team", path: league_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "division", label: "Conf / Div", path: league_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "pick", label: "Pick", path: league_path(@league))
            th(class: "text-right bg-base-100") { render_points_header(query) }
          end
        end
        if rows.empty?
          tbody { render_empty_row(STANDINGS_COLUMNS) }
        else
          rows.each { |row| render_standings_row(row) }
        end
      end
    end
  end

  def render_points_header(query)
    next_dir = (query.sort_column == "points" && query.sort_dir == "asc") ? "desc" : "asc"
    arrow = if query.sort_column == "points"
      (query.sort_dir == "asc") ? "▲" : "▼"
    else
      "↕"
    end
    href_params = query.to_url_params(sort: "points", dir: next_dir)
    a(href: "#{league_path(@league)}?#{href_params.to_query}",
      class: "link link-hover inline-flex items-center gap-1",
      data: {turbo_action: "advance"}) do
      plain "Points"
      span(class: "text-xs opacity-60") { arrow }
    end
  end

  def render_standings_row(row)
    team = row.team
    pick = row.pick
    panel_id = "breakdown-#{row.season_team.id}"

    # Every picked team gets a toggle, even with zero scoring — the panel
    # renders the breakdown or "No scoring yet." It's a persistent visual
    # affordance, not a "this row happens to have data" cue.
    tbody(data: pick ? {controller: "disclosure"} : nil) do
      tr do
        th(class: "align-middle") { render_breakdown_toggle(pick.present?, panel_id) }
        th { render_team_swatch(team) }
        td do
          div(class: "flex flex-col") do
            a(href: season_team_path(@league_season.season, slug: team.slug),
              class: "link link-hover font-medium") { team.name }
            span(class: "text-xs opacity-60") { team.abbreviation }
          end
        end
        td(class: "text-sm whitespace-nowrap") { division_label(team) || "—" }
        td(class: "text-sm whitespace-nowrap") { render_directory_pick_cell(pick) }
        th(class: "font-mono text-right") { row.points.to_s }
      end
      if pick
        tr(id: panel_id, class: "hidden", data: {disclosure_target: "panel"}) do
          td(colspan: STANDINGS_COLUMNS.to_s, class: "bg-base-200/50") do
            render_breakdown(row.events)
          end
        end
      end
    end
  end

  def render_empty_row(colspan)
    tr { td(colspan: colspan.to_s) { div(class: "alert alert-info my-2") { span { "No teams match these filters." } } } }
  end

  def render_breakdown_toggle(expandable, panel_id)
    return unless expandable
    button(type: "button", class: "btn btn-ghost btn-xs",
      aria_expanded: "false", aria_controls: panel_id,
      title: "Show scoring breakdown",
      data: {action: "click->disclosure#toggle"}) do
      span(class: "inline-block transition-transform",
        data: {disclosure_target: "icon"}) { "▸" }
    end
  end

  def render_directory_pick_cell(pick)
    if pick.nil?
      span(class: "opacity-50") { "—" }
    else
      span(class: "font-mono mr-1") { "##{pick.pick_number}" }
      span { pick.participant.display_name }
      if pick.autopicked
        span(class: "badge badge-xs badge-warning badge-outline ml-1") { "auto" }
      end
    end
  end

  def render_directory_action_cell(query, season_team, pick, on_the_clock)
    return if pick
    return unless can_pick?(on_the_clock)
    # Carry current sort/filter in the POST URL so the post-pick redirect
    # can preserve them (DraftPicksController#create reads them back out).
    # turbo-frame="_top" breaks out of the surrounding team_directory frame
    # so the response is treated as a full page swap. Needed because the
    # final pick flips status to in_season and the response no longer
    # contains the team_directory frame (it shows Standings instead).
    button_to "Pick", league_draft_picks_path(@league, **query.to_url_params),
      method: :post,
      params: {season_team_id: season_team.id},
      form: {class: "inline", data: {turbo_frame: "_top"}},
      class: "btn btn-primary btn-sm"
  end

  def render_team_swatch(team)
    if team.logo_url.present?
      img(src: team.logo_url, alt: "#{team.name} logo", width: 28, height: 28, class: "inline-block")
    else
      style = team.primary_color.present? ? "background-color: #{team.primary_color}" : nil
      span(
        class: "inline-flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold text-neutral-content bg-neutral",
        style: style
      ) { team.abbreviation.to_s[0, 3] }
    end
  end

  def division_label(team)
    parts = [team.conference, team.division].compact_blank
    parts.empty? ? nil : parts.join(" ")
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

  EVENT_LABELS = {
    "regular_win" => "Regular-season wins",
    "playoff_appearance" => "Playoff appearance",
    "divisional_appearance" => "Divisional round",
    "conference_appearance" => "Conference championship",
    "championship_appearance" => "Super Bowl appearance",
    "championship_win" => "Super Bowl win"
  }.freeze

  def render_breakdown(events)
    nonzero = events.reject { |_, points| points.zero? }
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
