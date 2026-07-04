# frozen_string_literal: true

class Views::Seasons::Show < Views::Base
  include Views::Components::TeamDirectoryHelpers
  include Views::Components::ScoringBreakdownHelpers

  # tbody disclosure rows span the full column set when expanded.
  # Standings: chevron | swatch | Team | Division | W-L | Points
  # Division:  chevron | swatch | Team | W-L | Points
  STANDINGS_COLUMNS = 6
  DIVISION_COLUMNS = 5

  def initialize(season:, standings_query:, league_leaders:)
    @season = season
    @standings_query = standings_query
    @league_leaders = league_leaders
  end

  def view_template
    render Views::Layouts::Application.new(title: @season.label) do
      main(class: "py-6 space-y-4") do
        render Views::Components::Breadcrumbs.new(trail: [
          ["Seasons", seasons_path],
          [@season.label, nil]
        ])

        div(class: "flex items-center justify-between gap-3") do
          h1(class: "text-3xl font-bold") { @season.label }
          span(class: "badge #{status_color(@season.status)}") { @season.status }
        end

        render_tabs
      end
    end
  end

  private

  def standings
    @standings ||= @standings_query.rows
  end

  def scoring_rules
    @scoring_rules ||= Scoring::Rules.for(@season.sport)
  end

  def render_tabs
    div(class: "tabs tabs-lift") do
      input(type: "radio", name: "season_tabs", class: "tab",
        aria_label: "Teams", checked: true)
      div(class: "tab-content bg-base-100 border-base-300 p-4") { render_teams_tab }

      if @league_leaders.any?
        input(type: "radio", name: "season_tabs", class: "tab", aria_label: "Leagues")
        div(class: "tab-content bg-base-100 border-base-300 p-4") { render_leagues_tab }
      end
    end
  end

  def render_teams_tab
    if standings.empty?
      p(class: "text-base-content/60") { "No teams in this season yet." }
      return
    end

    # Link tabs (not CSS radio tabs) so the active view lives in the URL
    # and can be shared; switching is a full-page navigation like sorting.
    div(class: "tabs tabs-border", role: "tablist") do
      render_view_tab("Standings", view: "standings")
      render_view_tab("By division", view: "division")
    end
    div(class: "pt-3") do
      (@standings_query.view == "division") ? render_teams_by_division : render_standings_table
    end
  end

  def render_view_tab(label, view:)
    active = @standings_query.view == view
    override = (view == "standings") ? nil : view
    a(href: season_path(@season, **@standings_query.to_url_params(view: override)),
      role: "tab", aria_selected: active.to_s,
      class: active ? "tab tab-active" : "tab") { label }
  end

  def render_teams_by_division
    grouped = standings.group_by { |r| [r.team.conference, r.team.division] }
      .sort_by { |(conf, div), _| [conf.to_s, div.to_s] }

    div(class: "grid grid-cols-1 sm:grid-cols-2 gap-4") do
      grouped.each do |(conference, division), rows|
        div do
          h3(class: "text-sm font-semibold uppercase tracking-wide opacity-70 mb-1") do
            plain [conference, division].compact.join(" ")
          end
          render_division_table(rows)
        end
      end
    end
  end

  def render_division_table(rows)
    div(class: "overflow-x-auto") do
      table(class: "table table-sm") do
        thead do
          tr do
            th(class: "w-8")
            th(class: "w-10")
            render_sortable_th("name", "Team")
            render_sortable_th("record", "W-L", class_name: "text-right")
            render_sortable_th("points", "Points", class_name: "text-right")
          end
        end
        rows.each { |row| render_team_row(row, columns: DIVISION_COLUMNS, show_division: false) }
      end
    end
  end

  def render_standings_table
    div(class: "overflow-x-auto") do
      table(class: "table table-sm") do
        thead do
          tr do
            th(class: "w-8")
            th(class: "w-10")
            render_sortable_th("name", "Team")
            render_sortable_th("division", "Division", class_name: "hidden sm:table-cell")
            render_sortable_th("record", "W-L", class_name: "text-right")
            render_sortable_th("points", "Points", class_name: "text-right")
          end
        end
        standings.each { |row| render_team_row(row, columns: STANDINGS_COLUMNS, show_division: true) }
      end
    end
  end

  # Each row gets its own <tbody> so the disclosure Stimulus controller
  # scopes to a single panel target. daisyUI's table-zebra rule targets
  # `tbody tr:nth-child(2n)` which can't match this layout - stripe at
  # the <tbody> level via :nth-child(even); thead is child 1 so tbodies
  # alternate cleanly from child 2.
  def render_team_row(row, columns:, show_division:)
    team = row.team
    panel_id = "season-breakdown-#{row.season_team.id}"
    tbody(class: "even:bg-base-200", data: {controller: "disclosure"}) do
      tr do
        th(class: "align-middle") { render_disclosure_toggle(panel_id) }
        td { render_team_swatch(team) }
        td(class: "font-medium") do
          a(href: season_team_path(@season, slug: team.slug), class: "link link-hover") do
            plain team.name
          end
        end
        if show_division
          td(class: "text-sm whitespace-nowrap hidden sm:table-cell") { plain(division_label(team) || "-") }
        end
        td(class: "text-right font-mono whitespace-nowrap") { plain combined_record(row) }
        th(class: "text-right font-mono") { row.points.to_s }
      end
      tr(id: panel_id, class: "hidden", data: {disclosure_target: "panel"}) do
        td(colspan: columns.to_s, class: "bg-base-200/50") do
          render_breakdown_body(row)
        end
      end
    end
  end

  def render_breakdown_body(row)
    div(class: "space-y-1 py-2 text-sm") do
      div(class: "flex flex-wrap justify-end gap-x-6 gap-y-1") do
        div do
          span(class: "opacity-70 mr-2") { "Regular" }
          span(class: "font-mono tabular-nums") { format_record(row.reg_w, row.reg_l, row.reg_t) }
        end
        if row.po_w.positive? || row.po_l.positive? || row.po_t.positive?
          div do
            span(class: "opacity-70 mr-2") { "Playoffs" }
            span(class: "font-mono tabular-nums") { format_record(row.po_w, row.po_l, row.po_t) }
          end
        end
      end
      render_scoring_breakdown(scoring_rules, row.events)
    end
  end

  def render_disclosure_toggle(panel_id)
    button(type: "button", class: "btn btn-ghost btn-xs",
      aria_expanded: "false", aria_controls: panel_id,
      title: "Show record and scoring breakdown",
      data: {action: "click->disclosure#toggle"}) do
      span(class: "inline-block transition-transform",
        data: {disclosure_target: "icon"}) do
        render Views::Components::Icon.new(:chevron_right)
      end
    end
  end

  def render_sortable_th(column, label, class_name: nil)
    render Views::Components::SortableHeader.new(
      query: @standings_query,
      column: column,
      label: label,
      path: season_path(@season),
      class_name: class_name
    )
  end

  def render_leagues_tab
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra") do
        thead do
          tr do
            th { "League" }
            th { "Top participant" }
            th(class: "text-right") { "Top score" }
            th(class: "text-right") { "Seats" }
          end
        end
        tbody do
          @league_leaders.each do |row|
            tr do
              td do
                a(href: league_path(row.league_season.league), class: "link link-hover font-medium") do
                  plain row.league_season.league.name
                end
              end
              td { plain(row.top_participant&.display_name || "-") }
              td(class: "text-right font-mono font-semibold") { row.top_score.to_s }
              td(class: "text-right text-sm opacity-60") { "#{row.filled_seats}/#{row.total_seats}" }
            end
          end
        end
      end
    end
  end

  def combined_record(row)
    format_record(row.reg_w + row.po_w, row.reg_l + row.po_l, row.reg_t + row.po_t)
  end

  def format_record(w, l, t)
    t.zero? ? "#{w}-#{l}" : "#{w}-#{l}-#{t}"
  end

  def status_color(status)
    {"active" => "badge-success", "upcoming" => "badge-info", "completed" => "badge-ghost"}[status] || "badge-ghost"
  end
end
