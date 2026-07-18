# frozen_string_literal: true

class Views::Leagues::History < Views::Base
  def initialize(league:, league_seasons:)
    @league = league
    @league_seasons = league_seasons
  end

  def view_template
    render Views::Layouts::Application.new(title: "#{@league.name} · History") do
      main(class: "py-6 space-y-4") do
        render Views::Components::Breadcrumbs.new(trail: [
          [@league.name, league_path(@league)],
          ["History", nil]
        ])

        h1(class: "text-3xl font-bold") { "#{@league.name} · history" }

        if @league_seasons.empty?
          p(class: "text-base-content/70") { "This league has no seasons yet." }
        else
          div(class: "card bg-base-100 shadow") do
            div(class: "card-body") do
              ul(class: "divide-y divide-base-300") do
                @league_seasons.each { |ls| render_row(ls) }
              end
            end
          end
        end
      end
    end
  end

  private

  def render_row(ls)
    li(class: "py-2 flex items-center justify-between gap-3") do
      div do
        a(href: league_season_path(@league, year: ls.season.year), class: "link link-hover font-medium") do
          plain ls.season.label
        end
        span(class: "badge badge-sm badge-ghost ml-2") { ls.status }
      end
      span(class: "text-sm opacity-70") { "#{ls.size} seats" }
    end
  end
end
