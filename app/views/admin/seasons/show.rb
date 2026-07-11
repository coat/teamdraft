# frozen_string_literal: true

class Views::Admin::Seasons::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(season:, stats:)
    @season = season
    @stats = stats
  end

  def view_template
    render Views::Layouts::Admin.new(
      title: @season.label,
      section: :seasons,
      breadcrumbs: [["Seasons", admin_seasons_path], [@season.label, nil]]
    ) do
      render_header
      render_metadata
      render_counts
      render_sync_panel
      render_switch_provider_panel
    end
  end

  private

  def render_header
    render Views::Components::Admin::PageHeader.new(title: @season.label) do
      span(class: "badge #{status_color}") { @season.status }
      a(href: edit_admin_season_path(@season), class: "btn btn-ghost btn-sm inline-flex items-center gap-1") do
        render Views::Components::Icon.new(:pencil_square)
        plain "Edit"
      end
      if @season.status != "active"
        button_to "Activate", activate_admin_season_path(@season),
          method: :post, form: {class: "inline"}, class: "btn btn-sm"
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
          stat("Dates") { render_date_range }
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
        if @season.status == "active"
          div(class: "flex items-center justify-between mt-3") do
            if @season.sync_paused?
              span(class: "badge badge-warning") { "Automated sync paused" }
            else
              span(class: "text-sm text-base-content/50") { "Automated sync active" }
            end
            pause_label = @season.sync_paused? ? "Resume sync" : "Pause sync"
            button_to pause_label, toggle_sync_pause_admin_season_path(@season),
              method: :post, form: {class: "inline"},
              class: "btn btn-sm #{@season.sync_paused? ? "btn-warning" : "btn-ghost"}"
          end
        end
        render Views::Components::Admin::SyncActions.new(season: @season, back_path: admin_season_path(@season))
      end
    end
  end

  def render_switch_provider_panel
    drafting = @season.league_seasons.where(status: "drafting").any?
    has_picks = @season.league_seasons.joins(:draft_picks).any?

    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Switch Data Provider" }
        p(class: "text-sm text-base-content/70") do
          plain "Changes the external API used to pull game schedules and scores, then queues a re-sync for yesterday and today. Existing game records are kept; the new provider adds its own records going forward."
          plain " If the season has draft picks, scoring events are recomputed after re-sync." if has_picks
        end
        if drafting
          div(class: "alert alert-error mt-3 text-sm") do
            span { "A draft is currently in progress - provider cannot be switched until it completes." }
          end
        else
          if has_picks
            div(class: "alert alert-warning mt-3 text-sm") do
              span { "This season has league picks. Scoring events will be recomputed after the re-sync completes." }
            end
          end
          form_with(url: switch_provider_admin_season_path(@season), method: :post, class: "space-y-3 mt-3") do |f|
            div(class: "space-y-1") do
              f.label :new_provider, "Provider", class: "label label-text font-medium"
              f.select :new_provider,
                SportsData::Provider::PROVIDERS.keys,
                {selected: @season.external_provider},
                class: "select select-sm select-bordered w-full"
            end
            div(class: "space-y-1") do
              f.label :new_external_id, "External ID (leave blank to keep current)", class: "label label-text font-medium"
              f.text_field :new_external_id, value: @season.external_id,
                class: "input input-sm input-bordered w-full"
            end
            f.submit "Switch & Re-sync", class: "btn btn-sm btn-warning"
          end
        end
      end
    end
  end

  def status_color
    {"active" => "badge-success", "upcoming" => "badge-info", "completed" => "badge-ghost"}.fetch(@season.status, "badge-ghost")
  end

  def stat(label_text, value = nil, &block)
    div do
      dt(class: "text-xs uppercase tracking-wide opacity-60") { label_text }
      dd(class: "font-medium") do
        block ? yield : plain(value.to_s)
      end
    end
  end

  def render_date_range
    if @season.starts_on.blank? && @season.ends_on.blank?
      plain "-"
    else
      span(class: "inline-flex items-center gap-1") do
        plain(@season.starts_on&.iso8601 || "?")
        render Views::Components::Icon.new(:arrow_long_right, class_name: "size-3 opacity-60")
        plain(@season.ends_on&.iso8601 || "?")
      end
    end
  end

  def external_label
    return "-" if @season.external_id.blank?
    "#{@season.external_provider.presence || "?"} · #{@season.external_id}"
  end
end
