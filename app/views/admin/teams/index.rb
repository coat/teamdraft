# frozen_string_literal: true

class Views::Admin::Teams::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::Request

  def initialize(query:, teams:, sports:, pagy:, top_ids: Set.new, bottom_ids: Set.new)
    @query = query
    @teams = teams
    @sports = sports
    @pagy = pagy
    @top_ids = top_ids
    @bottom_ids = bottom_ids
  end

  def view_template
    render Views::Layouts::Admin.new(title: "Teams", section: :teams, breadcrumbs: [["Teams", nil]]) do
      render Views::Components::Admin::PageHeader.new(
        title: "Teams",
        subtitle: "External ID is what links a team to its provider (e.g. TheSportsDB's idTeam). Required for game sync."
      )
      render_filter_card
      render Views::Components::Admin::TableCard.new do
        thead do
          tr do
            th(scope: "col") { "Sport" }
            render Views::Components::SortableHeader.new(query: @query, column: "name", label: "Name", path: admin_teams_path)
            th(scope: "col") { "Abbr" }
            th(scope: "col") { "Conf/Div" }
            th(scope: "col") { "External ID" }
            render Views::Components::SortableHeader.new(query: @query, column: "rank", label: "Pick rank", path: admin_teams_path)
            th(colspan: 3, scope: "colgroup") { "Actions" }
          end
        end
        tbody do
          @teams.each { |team| render_row(team) }
        end
      end
      render Views::Components::Admin::Pagination.new(pagy: @pagy)
    end
  end

  private

  def list_params
    request.query_parameters.slice("q", "sport_id", "sort", "dir", "page").symbolize_keys
  end

  def render_filter_card
    render Views::Components::Admin::FilterCard.new(url: admin_teams_path, query: @query) do |form|
      div(class: "space-y-1") do
        form.label :sport_id, "Sport", class: "label label-text text-xs uppercase tracking-wide"
        form.select :sport_id,
          [["All sports", ""]] + @sports,
          {selected: @query.sport_id},
          class: "select select-bordered"
      end
      div(class: "space-y-1") do
        form.label :q, "Search", class: "label label-text text-xs uppercase tracking-wide"
        form.text_field :q, value: @query.search_term, placeholder: "Team name…",
          class: "input input-bordered w-48"
      end
    end
  end

  def render_row(team)
    tr(class: team.external_id.blank? ? "bg-warning/10" : nil) do
      td { team.sport.key }
      td(class: "font-medium") { team.name }
      td { team.abbreviation }
      td { "#{team.conference}/#{team.division}" }
      td { team.external_id.presence || span(class: "opacity-50") { "-" } }
      td { team.default_pick_rank&.to_s || span(class: "opacity-50") { "-" } }
      td(class: "w-4 text-center") do
        if team.default_pick_rank.nil? || @top_ids.include?(team.id)
          span(class: "btn btn-ghost btn-xs btn-disabled px-0.5", aria_hidden: "true") { render Views::Components::Icon.new(:chevron_up) }
        else
          button_to move_up_admin_team_path(team, **list_params), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs px-0.5",
            title: "Move up in draft order",
            aria: {label: "Move up in draft order"} do
            render Views::Components::Icon.new(:chevron_up)
          end
        end
      end
      td(class: "w-4 text-center") do
        if team.default_pick_rank.nil? || @bottom_ids.include?(team.id)
          span(class: "btn btn-ghost btn-xs btn-disabled px-0.5", aria_hidden: "true") { render Views::Components::Icon.new(:chevron_down) }
        else
          button_to move_down_admin_team_path(team, **list_params), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs px-0.5",
            title: "Move down in draft order",
            aria: {label: "Move down in draft order"} do
            render Views::Components::Icon.new(:chevron_down)
          end
        end
      end
      td do
        a(href: edit_admin_team_path(team), class: "btn btn-ghost btn-xs",
          title: "Edit", aria_label: "Edit") do
          render Views::Components::Icon.new(:pencil_square)
        end
      end
    end
  end
end
