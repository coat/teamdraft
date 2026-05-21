# frozen_string_literal: true

class Views::Seasons::Show < Views::Base
  def initialize(season:, standings:, league_leaders:)
    @season = season
    @standings = standings
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

  def render_tabs
    div(class: "tabs tabs-box") do
      input(type: "radio", name: "season_tabs", class: "tab",
        aria_label: "Teams", checked: true)
      div(class: "tab-content bg-base-100 p-4") { render_teams_tab }

      if @league_leaders.any?
        input(type: "radio", name: "season_tabs", class: "tab", aria_label: "Leagues")
        div(class: "tab-content bg-base-100 p-4") { render_leagues_tab }
      end
    end
  end

  def render_teams_tab
    if @standings.empty?
      p(class: "text-base-content/60") { "No teams in this season yet." }
      return
    end

    div(class: "tabs tabs-border") do
      input(type: "radio", name: "teams_view", class: "tab",
        aria_label: "Standings", checked: true)
      div(class: "tab-content pt-3") { render_standings_table }

      input(type: "radio", name: "teams_view", class: "tab",
        aria_label: "By division")
      div(class: "tab-content pt-3") { render_teams_by_division }
    end
  end

  def render_teams_by_division
    grouped = @standings
      .sort_by { |r| [r.team.conference || "", r.team.division || "", r.team.name] }
      .group_by { |r| [r.team.conference, r.team.division] }

    div(class: "grid grid-cols-1 sm:grid-cols-2 gap-4") do
      grouped.each do |(conference, division), rows|
        div do
          h3(class: "text-sm font-semibold uppercase tracking-wide opacity-70 mb-1") do
            plain [conference, division].compact.join(" ")
          end
          ul(class: "space-y-1") do
            rows.each do |row|
              li do
                a(href: season_team_path(@season, slug: row.team.slug), class: "link link-hover") do
                  plain "#{row.team.abbreviation} · #{row.team.name}"
                end
              end
            end
          end
        end
      end
    end
  end

  def render_standings_table
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra") do
        thead do
          tr do
            th { "Team" }
            th { "Division" }
            th(class: "text-right") { "Reg" }
            th(class: "text-right") { "Playoffs" }
            th(class: "text-right") { "Points" }
          end
        end
        tbody do
          @standings.each do |row|
            tr do
              td do
                a(href: season_team_path(@season, slug: row.team.slug), class: "link link-hover font-medium") do
                  plain "#{row.team.abbreviation} · #{row.team.name}"
                end
              end
              td(class: "text-sm opacity-70") { plain [row.team.conference, row.team.division].compact.join(" ") }
              td(class: "text-right font-mono") { plain format_record(row.reg_w, row.reg_l, row.reg_t) }
              td(class: "text-right font-mono") { plain playoff_cell(row) }
              td(class: "text-right font-mono font-semibold") { row.points.to_s }
            end
          end
        end
      end
    end
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
              td { plain(row.top_participant&.display_name || "—") }
              td(class: "text-right font-mono font-semibold") { row.top_score.to_s }
              td(class: "text-right text-sm opacity-60") { "#{row.filled_seats}/#{row.total_seats}" }
            end
          end
        end
      end
    end
  end

  def format_record(w, l, t)
    t.zero? ? "#{w}-#{l}" : "#{w}-#{l}-#{t}"
  end

  def playoff_cell(row)
    return "—" if row.po_w.zero? && row.po_l.zero? && row.po_t.zero?
    format_record(row.po_w, row.po_l, row.po_t)
  end

  def status_color(status)
    {"active" => "badge-success", "upcoming" => "badge-info", "completed" => "badge-ghost"}[status] || "badge-ghost"
  end
end
