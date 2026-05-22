# frozen_string_literal: true

class Views::Admin::Seasons::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(seasons:, pagy:)
    @seasons = seasons
    @pagy = pagy
  end

  def view_template
    render Views::Layouts::Admin.new(title: "Seasons", section: :seasons, breadcrumbs: [["Seasons", nil]]) do
      render Views::Components::Admin::PageHeader.new(
        title: "Seasons",
        subtitle: "External ID is the provider's season key (e.g. TheSportsDB's idLeague + year code). Required for game sync."
      ) do
        a(href: new_admin_season_path, class: "btn btn-primary btn-sm") { "New season" }
      end
      render Views::Components::Admin::TableCard.new do
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
      render Views::Components::Admin::Pagination.new(pagy: @pagy)
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
        a(href: edit_admin_season_path(season), class: "btn btn-ghost btn-xs",
          title: "Edit", aria_label: "Edit") do
          render Views::Components::Icon.new(:pencil_square)
        end
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
    if season.starts_on.blank? && season.ends_on.blank?
      span(class: "opacity-50") { "—" }
    else
      span(class: "inline-flex items-center gap-1") do
        plain(season.starts_on&.iso8601 || "?")
        render Views::Components::Icon.new(:arrow_long_right, class_name: "size-3 opacity-60")
        plain(season.ends_on&.iso8601 || "?")
      end
    end
  end
end
