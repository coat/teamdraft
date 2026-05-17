# frozen_string_literal: true

class Views::Admin::Seasons::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(seasons:)
    @seasons = seasons
  end

  def view_template
    render Views::Layouts::Application.new(title: "Admin · Seasons") do
      main(class: "py-6 space-y-4") do
        div(class: "flex items-center justify-between") do
          h1(class: "text-3xl font-bold") { "Seasons" }
          a(href: new_admin_season_path, class: "btn btn-primary btn-sm") { "New season" }
        end
        p(class: "text-sm text-base-content/70") do
          plain "External ID is the provider's season key (e.g. TheSportsDB's idLeague + year code). Required for game sync."
        end
        div(class: "card bg-base-100 shadow") do
          div(class: "overflow-x-auto") do
            table(class: "table table-sm table-zebra") do
              thead do
                tr do
                  th { "Sport" }
                  th { "Year" }
                  th { "Label" }
                  th { "Status" }
                  th { "Dates" }
                  th { "External" }
                  th
                end
              end
              tbody do
                @seasons.each { |season| render_row(season) }
              end
            end
          end
        end
      end
    end
  end

  private

  def render_row(season)
    tr(class: season.external_id.blank? ? "bg-warning/10" : nil) do
      td { season.sport.key }
      td(class: "font-mono") { season.year.to_s }
      td(class: "font-medium") do
        a(href: admin_season_path(season), class: "link link-hover") { season.label }
      end
      td { render_status(season.status) }
      td { date_range(season) }
      td(class: "text-sm") do
        if season.external_id.present?
          plain "#{season.external_provider.presence || "?"} · #{season.external_id}"
        else
          span(class: "opacity-50") { "—" }
        end
      end
      td(class: "flex flex-wrap gap-1 justify-end") do
        a(href: edit_admin_season_path(season), class: "btn btn-ghost btn-xs") { "Edit" }
        unless season.status == "active"
          button_to "Activate", activate_admin_season_path(season),
            method: :post, form: {class: "inline"},
            class: "btn btn-xs"
        end
      end
    end
  end

  def render_status(status)
    color = {"active" => "badge-success", "upcoming" => "badge-info", "completed" => "badge-ghost"}[status]
    span(class: "badge badge-sm #{color}") { status }
  end

  def date_range(season)
    return span(class: "opacity-50") { "—" } if season.starts_on.blank? && season.ends_on.blank?
    "#{season.starts_on&.iso8601 || "?"} → #{season.ends_on&.iso8601 || "?"}"
  end
end
