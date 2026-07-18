# frozen_string_literal: true

class Views::Seasons::Index < Views::Base
  def initialize(seasons:)
    @seasons = seasons
  end

  def view_template
    render Views::Layouts::Application.new(title: "Seasons") do
      main(class: "py-6 space-y-4") do
        h1(class: "text-3xl font-bold") { "Seasons" }
        if @seasons.empty?
          p(class: "text-base-content/70") { "No seasons yet." }
        else
          div(class: "card bg-base-100 shadow") do
            div(class: "card-body") do
              ul(class: "divide-y divide-base-300") do
                @seasons.each { |s| render_row(s) }
              end
            end
          end
        end
      end
    end
  end

  private

  def render_row(season)
    li(class: "py-2 flex items-center justify-between gap-3") do
      div(class: "flex items-center gap-3") do
        span(class: "badge badge-neutral badge-sm uppercase") { season.sport.key }
        a(href: season_path(season), class: "link link-hover font-medium") { season.label }
      end
      span(class: "badge badge-sm #{status_color(season.status)}") { season.status }
    end
  end

  def status_color(status)
    {"active" => "badge-success", "upcoming" => "badge-info", "completed" => "badge-ghost"}[status] || "badge-ghost"
  end
end
