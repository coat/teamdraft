# frozen_string_literal: true

class Views::Admin::Teams::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(query:, teams:, sports:, top_ids: Set.new, bottom_ids: Set.new)
    @query = query
    @teams = teams
    @sports = sports
    @top_ids = top_ids
    @bottom_ids = bottom_ids
  end

  def view_template
    render Views::Layouts::Application.new(title: "Admin · Teams") do
      main(class: "py-6 space-y-4") do
        h1(class: "text-3xl font-bold") { "Teams" }
        p(class: "text-sm text-base-content/70") do
          plain "External ID is what links a team to its provider (e.g. TheSportsDB's idTeam). Required for game sync."
        end
        render_filter_card
        div(class: "card bg-base-100 shadow") do
          div(class: "overflow-x-auto") do
            table(class: "table table-sm table-zebra") do
              thead do
                tr do
                  th { "Sport" }
                  render Views::Components::Admin::SortableHeader.new(query: @query, column: "name", label: "Name", path: admin_teams_path)
                  th { "Abbr" }
                  th { "Conf/Div" }
                  th { "External ID" }
                  render Views::Components::Admin::SortableHeader.new(query: @query, column: "rank", label: "Pick rank", path: admin_teams_path)
                  th(colspan: 3) { "Actions" }
                end
              end
              tbody do
                @teams.each { |team| render_row(team) }
              end
            end
          end
        end
      end
    end
  end

  private

  def render_filter_card
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body p-4") do
        form_with(url: admin_teams_path, method: :get, scope: nil, local: true,
          class: "flex flex-wrap items-end gap-3") do |form|
          div(class: "space-y-1") do
            form.label :sport_id, "Sport", class: "label label-text text-xs uppercase tracking-wide opacity-60"
            form.select :sport_id,
              [["All sports", ""]] + @sports,
              {selected: @query.sport_id},
              class: "select select-bordered"
          end
          div(class: "space-y-1") do
            form.label :q, "Search", class: "label label-text text-xs uppercase tracking-wide opacity-60"
            form.text_field :q, value: @query.search_term, placeholder: "Team name…",
              class: "input input-bordered w-48"
          end
          form.hidden_field :sort, value: @query.sort_column
          form.hidden_field :dir, value: @query.sort_dir
          div(class: "flex gap-2") do
            form.submit "Filter", class: "btn btn-primary"
            a(href: admin_teams_path, class: "btn btn-ghost") { "Clear" }
          end
        end
      end
    end
  end

  def render_row(team)
    tr(class: team.external_id.blank? ? "bg-warning/10" : nil) do
      td { team.sport.key }
      td(class: "font-medium") { team.name }
      td { team.abbreviation }
      td { "#{team.conference}/#{team.division}" }
      td { team.external_id.presence || span(class: "opacity-50") { "—" } }
      td { team.default_pick_rank&.to_s || span(class: "opacity-50") { "—" } }
      td(class: "w-4 text-center") do
        if team.default_pick_rank && !@top_ids.include?(team.id)
          button_to "▲", move_up_admin_team_path(team), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs px-0.5",
            title: "Move up in draft order"
        end
      end
      td(class: "w-4 text-center") do
        if team.default_pick_rank && !@bottom_ids.include?(team.id)
          button_to "▼", move_down_admin_team_path(team), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs px-0.5",
            title: "Move down in draft order"
        end
      end
      td { a(href: edit_admin_team_path(team), class: "btn btn-ghost btn-xs") { "Edit" } }
    end
  end
end
