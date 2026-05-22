# frozen_string_literal: true

class Views::Leagues::Show < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::TurboStreamFrom
  include Components::Helpers::CurrentUser
  include Views::Components::TeamDirectoryHelpers

  STANDINGS_COLUMNS = 6

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
        if post_draft_with_picks
          render_post_draft_directory
        elsif viewable? && claimed? && @league_season && !draft_finished?
          # Belt-and-suspenders: LeaguesController#show redirects claimed
          # viewers to the draft room while drafting, but if a render slips
          # through (admin, sneak path) show a clear CTA instead of nothing.
          render_draft_cta
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
          a(href: edit_league_path(@league), class: "btn btn-ghost btn-sm inline-flex items-center gap-1") do
            render Views::Components::Icon.new(:pencil_square)
            plain "Edit league"
          end
        end
      end
    end
  end

  def render_season_chip
    return unless @league_season&.season
    a(href: season_path(@league_season.season), class: "badge badge-ghost badge-sm mt-1 link link-hover") do
      plain @league_season.season.label
    end
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

  def render_draft_cta
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { draft_cta_title }
        p(class: "text-base-content/70") { draft_cta_subtitle } if draft_cta_subtitle
        div(class: "card-actions") do
          a(href: league_draft_path(@league), class: "btn btn-primary inline-flex items-center gap-1") do
            plain draft_cta_button_label
            render Views::Components::Icon.new(:chevron_right)
          end
        end
      end
    end
  end

  def draft_cta_title
    return "Draft is in progress" if @league_season.status == "drafting"
    starts_at = @league_season.draft_scheduled_at
    return "Draft scheduled" if starts_at.present? && starts_at > Time.current
    "Draft hasn't started yet"
  end

  def draft_cta_subtitle
    return nil unless @league_season.status == "draft_pending"
    if @league_season.participants.where(joined_at: nil).any?
      "Waiting for the other player to claim their seat."
    elsif (starts_at = @league_season.draft_scheduled_at).present? && starts_at > Time.current
      "Starts #{starts_at.strftime("%a %b %-d at %-l:%M %p %Z")}."
    end
  end

  def draft_cta_button_label
    (@league_season.status == "drafting") ? "Go to the draft room" : "Open the draft room"
  end

  def render_post_draft_directory
    h2(class: "text-xl font-semibold mt-2") { "Standings" }
    render_team_directory
  end

  def render_team_directory
    query = directory_query
    rows = query.rows
    divisions = all_division_labels

    turbo_frame_tag "team_directory", class: "space-y-3 mt-4 block" do
      render_directory_filters(query, divisions)
      render_standings_table(query, rows)
    end
  end

  def directory_query
    @directory_query ||= Leagues::DirectoryQuery.new(league_season: @league_season, params: {}, user: current_user)
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

  def render_standings_table(query, rows)
    # -mx-4 sm:mx-0: let the table reach the viewport edges on phones,
    # outside the layout's px-4 gutter. The filters above keep the
    # gutter so they don't sit flush against the screen edge.
    # bg-base-100 + sm:border/sm:rounded: give the table its own surface
    # (matches the draft room's tab-content panel) so the zebra rows have
    # contrast against the page background. Edge-to-edge on phones,
    # rounded/bordered on desktop.
    div(class: "overflow-x-auto -mx-4 sm:mx-0 bg-base-100 sm:rounded-box sm:border sm:border-base-300") do
      table(class: "table table-sm") do
        thead do
          tr do
            th(class: "w-8")
            th(class: "w-10")
            render Views::Components::SortableHeader.new(query: query, column: "name", label: "Team", path: league_path(@league))
            render Views::Components::SortableHeader.new(query: query, column: "division", label: "Conf / Div", path: league_path(@league), class_name: "hidden sm:table-cell")
            render Views::Components::SortableHeader.new(query: query, column: "pick", label: "Pick", path: league_path(@league))
            th(class: "text-right") { render_points_header(query) }
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
    arrow_name = if query.sort_column == "points"
      (query.sort_dir == "asc") ? :chevron_up : :chevron_down
    else
      :chevron_up_down
    end
    href_params = query.to_url_params(sort: "points", dir: next_dir)
    a(href: "#{league_path(@league)}?#{href_params.to_query}",
      class: "link link-hover inline-flex items-center gap-1",
      data: {turbo_action: "advance"}) do
      plain "Points"
      span(class: "opacity-60") { render Views::Components::Icon.new(arrow_name, class_name: "size-3") }
    end
  end

  def render_standings_row(row)
    team = row.team
    pick = row.pick
    panel_id = "breakdown-#{row.season_team.id}"

    # even:bg-base-200 — daisyUI's table-zebra targets
    # `tbody tr:nth-child(2n)`, which never matches here because each row
    # gets its own <tbody> (required so the Stimulus disclosure
    # controller scopes to a single panel target). Instead, stripe at
    # the <tbody> level via :nth-child(even); the thead is child 1, so
    # tbodies alternate cleanly starting from child 2.
    tbody(class: "even:bg-base-200", data: pick ? {controller: "disclosure"} : nil) do
      tr do
        th(class: "align-middle") { render_breakdown_toggle(pick.present?, panel_id) }
        th { render_team_swatch(team) }
        td(class: "font-medium") do
          a(href: season_team_path(@league_season.season, slug: team.slug),
            class: "link link-hover") { team.name }
        end
        td(class: "text-sm whitespace-nowrap hidden sm:table-cell") { division_label(team) || "—" }
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

  def standings_rows
    @standings_rows ||= Standings::Calculate.call(league_season: @league_season)
  end

  def render_leaderboard(rows)
    leader_points = rows.first.total_points
    has_leader = leader_points.positive?
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body p-3 sm:p-6") do
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
