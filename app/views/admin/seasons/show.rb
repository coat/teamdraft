# frozen_string_literal: true

class Views::Admin::Seasons::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(season:, stats:)
    @season = season
    @stats = stats
  end

  def view_template
    render Views::Layouts::Application.new(title: "Admin · #{@season.label}") do
      main(class: "py-6 space-y-4") do
        render_header
        render_metadata
        render_counts
        render_sync_panel
      end
    end
  end

  private

  def render_header
    div(class: "flex items-center justify-between gap-4") do
      div do
        div(class: "text-sm text-base-content/60") do
          a(href: admin_seasons_path, class: "link link-hover") { "← Seasons" }
        end
        h1(class: "text-3xl font-bold") { @season.label }
        span(class: "badge badge-sm #{status_color}") { @season.status }
      end
      div(class: "flex flex-wrap gap-2") do
        a(href: edit_admin_season_path(@season), class: "btn btn-ghost btn-sm") { "Edit" }
        if @season.status != "active"
          button_to "Activate", activate_admin_season_path(@season),
            method: :post, form: {class: "inline"}, class: "btn btn-sm"
        end
      end
    end
  end

  def render_metadata
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Details" }
        dl(class: "grid grid-cols-2 sm:grid-cols-4 gap-3 mt-2 text-sm") do
          stat("Sport", @season.sport.name)
          stat("Year", @season.year.to_s)
          stat("Dates", date_range)
          stat("External", external_label)
        end
      end
    end
  end

  def render_counts
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Counts" }
        dl(class: "grid grid-cols-2 sm:grid-cols-4 gap-3 mt-2 text-sm") do
          stat("Games", "#{@stats[:games]} (#{@stats[:games_final]} final)")
          stat("Scoring events", @stats[:scoring_events].to_s)
          stat("League seasons", @stats[:league_seasons].to_s)
        end
      end
    end
  end

  def render_sync_panel
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Sync" }
        p(class: "text-sm text-base-content/70") do
          plain "Pull game results from the external provider, then recompute scoring events from the local game data. Safe to backfill on completed seasons."
        end
        if @season.external_id.blank?
          div(class: "alert alert-warning") do
            span { "This season has no external_id, so the game sync will no-op. Set one via Edit." }
          end
        end
        render Views::Components::Admin::SyncActions.new(season: @season, back_path: admin_season_path(@season))
      end
    end
  end

  def status_color
    {"active" => "badge-success", "upcoming" => "badge-info", "completed" => "badge-ghost"}.fetch(@season.status, "badge-ghost")
  end

  def stat(label_text, value)
    div do
      dt(class: "text-xs uppercase tracking-wide opacity-60") { label_text }
      dd(class: "font-medium") { value.to_s }
    end
  end

  def date_range
    return "—" if @season.starts_on.blank? && @season.ends_on.blank?
    "#{@season.starts_on&.iso8601 || "?"} → #{@season.ends_on&.iso8601 || "?"}"
  end

  def external_label
    return "—" if @season.external_id.blank?
    "#{@season.external_provider.presence || "?"} · #{@season.external_id}"
  end
end
