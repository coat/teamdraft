# frozen_string_literal: true

class Views::Admin::Dashboard::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(stats:)
    @stats = stats
  end

  def view_template
    render Views::Layouts::Admin.new(title: "Dashboard", section: :dashboard) do
      render Views::Components::Admin::PageHeader.new(title: "Dashboard")
      render_counts
      render_syncs
      render_activity
    end
  end

  private

  def render_counts
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title text-base") { "Counts" }
        dl(class: "grid grid-cols-2 sm:grid-cols-3 gap-3 mt-2 text-sm") do
          stat("Leagues", "#{@stats[:leagues]} (#{@stats[:drafting_leagues]} mid-draft)")
          stat("Games", "#{@stats[:games]} (#{@stats[:games_final]} final)")
          stat("Scoring events", @stats[:scoring_events])
          stat("Users", "#{@stats[:users]} (#{@stats[:admins]} admin · #{@stats[:disabled_users]} disabled)")
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
        h2(class: "card-title text-base") { "Sync" }
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

  def render_activity
    div(class: "grid grid-cols-1 md:grid-cols-2 gap-4") do
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body") do
          h2(class: "card-title text-base") { "Recent leagues (7 days)" }
          if @stats[:recent_leagues].empty?
            p(class: "text-sm text-base-content/60") { "None." }
          else
            ul(class: "menu bg-base-100 w-full p-0 [&_li>*]:rounded-lg") do
              @stats[:recent_leagues].each do |league|
                li do
                  a(href: admin_league_path(league)) do
                    span(class: "font-medium") { league.name }
                    span(class: "text-xs opacity-60 ml-2") { league.created_at.strftime("%Y-%m-%d") }
                  end
                end
              end
            end
          end
        end
      end
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body") do
          h2(class: "card-title text-base") { "Recent users (7 days)" }
          if @stats[:recent_users].empty?
            p(class: "text-sm text-base-content/60") { "None." }
          else
            ul(class: "menu bg-base-100 w-full p-0 [&_li>*]:rounded-lg") do
              @stats[:recent_users].each do |user|
                li do
                  a(href: admin_user_path(user)) do
                    span(class: "font-medium") { user.email_address }
                    span(class: "text-xs opacity-60 ml-2") { user.created_at.strftime("%Y-%m-%d") }
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
