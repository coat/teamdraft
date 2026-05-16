# frozen_string_literal: true

class Views::Seasons::Show < Views::Base
  def initialize(season:, league_seasons:)
    @season = season
    @league_seasons = league_seasons
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

        render_teams
        render_leagues if @league_seasons.any?
      end
    end
  end

  private

  def render_teams
    grouped = @season.season_teams.sort_by { |st| [st.team.conference || "", st.team.division || "", st.team.name] }
      .group_by { |st| [st.team.conference, st.team.division] }

    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Teams" }
        if grouped.empty?
          p(class: "text-base-content/60") { "No teams in this season yet." }
        else
          div(class: "grid grid-cols-1 sm:grid-cols-2 gap-4 mt-2") do
            grouped.each do |(conference, division), teams|
              div do
                h3(class: "text-sm font-semibold uppercase tracking-wide opacity-70 mb-1") do
                  plain [conference, division].compact.join(" ")
                end
                ul(class: "space-y-1") do
                  teams.each do |st|
                    li do
                      a(href: season_team_path(@season, slug: st.team.slug), class: "link link-hover") do
                        plain "#{st.team.abbreviation} · #{st.team.name}"
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def render_leagues
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Public leagues" }
        ul(class: "divide-y divide-base-300 mt-1") do
          @league_seasons.each do |ls|
            li(class: "py-2 flex items-center justify-between gap-3") do
              a(href: league_path(ls.league), class: "link link-hover font-medium") { ls.league.name }
              span(class: "text-sm opacity-60") { "#{ls.participants.size}/#{ls.size} seats" }
            end
          end
        end
      end
    end
  end

  def status_color(status)
    {"active" => "badge-success", "upcoming" => "badge-info", "completed" => "badge-ghost"}[status] || "badge-ghost"
  end
end
