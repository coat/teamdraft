# frozen_string_literal: true

class Views::Admin::Dashboard::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(stats:)
    @stats = stats
  end

  def view_template
    render Views::Layouts::Application.new(title: "Admin") do
      main(class: "py-6 space-y-4") do
        h1(class: "text-3xl font-bold") { "Admin" }

        render_counts
        render_syncs
        render_links
      end
    end
  end

  private

  def render_counts
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Counts" }
        dl(class: "grid grid-cols-2 sm:grid-cols-3 gap-3 mt-2 text-sm") do
          stat("Leagues", "#{@stats[:leagues]} (#{@stats[:drafting_leagues]} mid-draft)")
          stat("Games", "#{@stats[:games]} (#{@stats[:games_final]} final)")
          stat("Scoring events", @stats[:scoring_events])
          stat("Users", @stats[:users])
        end
      end
    end
  end

  def stat(label, value)
    div do
      dt(class: "text-xs uppercase tracking-wide opacity-60") { label }
      dd(class: "font-medium") { value.to_s }
    end
  end

  def render_syncs
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Sync" }
        if @stats[:active_seasons].empty?
          p(class: "text-base-content/60") { "No active seasons." }
        else
          div(class: "space-y-3") do
            @stats[:active_seasons].each do |season|
              render Views::Components::Admin::SyncActions.new(season: season, back_path: admin_root_path)
            end
          end
        end
      end
    end
  end

  def render_links
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Manage" }
        ul(class: "menu bg-base-100 w-full p-0 [&_li>*]:rounded-lg") do
          li { a(href: admin_seasons_path) { "Seasons" } }
          li { a(href: admin_teams_path) { "Teams" } }
          li { a(href: admin_games_path) { "Games" } }
          li { a(href: admin_leagues_path) { "Leagues" } }
          li { a(href: admin_jobs_path) { "Jobs (Mission Control)" } }
        end
      end
    end
  end
end
