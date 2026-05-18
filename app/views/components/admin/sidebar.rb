# frozen_string_literal: true

class Views::Components::Admin::Sidebar < Views::Base
  GROUPS = [
    ["Overview", [
      [:dashboard, "Dashboard", :admin_root_path]
    ]],
    ["Manage", [
      [:leagues, "Leagues", :admin_leagues_path],
      [:seasons, "Seasons", :admin_seasons_path],
      [:teams, "Teams", :admin_teams_path],
      [:games, "Games", :admin_games_path],
      [:users, "Users", :admin_users_path]
    ]],
    ["System", [
      [:jobs, "Jobs", :admin_jobs_path]
    ]]
  ].freeze

  def initialize(current_section: nil)
    @current_section = current_section
  end

  def view_template
    aside(class: "w-64 min-h-full bg-base-100 border-r border-base-300") do
      div(class: "p-4 border-b border-base-300 hidden lg:block") do
        a(href: admin_root_path, class: "font-semibold text-lg") { "Team Draft Admin" }
      end
      nav(class: "p-3 space-y-4") do
        GROUPS.each do |label, items|
          div do
            div(class: "text-xs uppercase tracking-wide opacity-60 px-3 pb-1") { label }
            ul(class: "menu menu-sm p-0 [&_li>a]:rounded-lg w-full") do
              items.each do |key, item_label, path_helper|
                active = (key == @current_section)
                li do
                  a(href: send(path_helper), class: "#{active ? "menu-active font-medium" : ""}") { item_label }
                end
              end
            end
          end
        end
      end
    end
  end
end
