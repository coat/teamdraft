# frozen_string_literal: true

class Views::Admin::Leagues::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(query:, leagues:, pagy:)
    @query = query
    @leagues = leagues
    @pagy = pagy
  end

  def view_template
    render Views::Layouts::Admin.new(title: "Leagues", section: :leagues, breadcrumbs: [["Leagues", nil]]) do
      render Views::Components::Admin::PageHeader.new(
        title: "Leagues",
        subtitle: "Each row reflects the league's current season. Destructive controls: edit fields (including status), or delete the entire league. Deletion cascades to every season's participants and draft picks."
      )
      render_filter_card
      render_table_card
      render Views::Components::Admin::Pagination.new(pagy: @pagy)
    end
  end

  private

  def render_filter_card
    render Views::Components::Admin::FilterCard.new(url: admin_leagues_path, query: @query) do |form|
      div(class: "space-y-1") do
        form.label :q, "Search", class: "label label-text text-xs uppercase tracking-wide"
        form.text_field :q, value: @query.search_term, placeholder: "League name…",
          class: "input input-bordered w-64"
      end
      div(class: "space-y-1") do
        form.label :status, "Status", class: "label label-text text-xs uppercase tracking-wide"
        form.select :status,
          [["Any status", ""]] + LeagueSeason::STATUSES.map { |s| [s.humanize, s] },
          {selected: @query.status},
          class: "select select-bordered"
      end
      div(class: "space-y-1") do
        form.label :users, "Users", class: "label label-text text-xs uppercase tracking-wide"
        form.select :users,
          [["Any", ""], ["Has signed-up users", "yes"], ["Anonymous only", "no"]],
          {selected: @query.users},
          class: "select select-bordered"
      end
    end
  end

  def render_table_card
    render Views::Components::Admin::TableCard.new do
      thead do
        tr do
          render Views::Components::SortableHeader.new(query: @query, column: "name", label: "Name", path: admin_leagues_path)
          th(scope: "col") { "Current season" }
          th(scope: "col") { "Status" }
          th(scope: "col") { "Owner" }
          th(scope: "col") { "Users" }
          render Views::Components::SortableHeader.new(query: @query, column: "created_at", label: "Created", path: admin_leagues_path)
          th(scope: "col") { span(class: "sr-only") { "Actions" } }
        end
      end
      tbody do
        if @leagues.empty?
          tr do
            td(colspan: "7") do
              div(class: "alert alert-info my-2") { span { "No leagues match these filters." } }
            end
          end
        else
          @leagues.each { |league| render_row(league) }
        end
      end
    end
  end

  def render_row(league)
    ls = league.current_league_season
    participants = ls ? ls.participants.to_a : []
    user_count = participants.count { |p| p.user_id }
    tr(class: (user_count.zero? ? "bg-warning/10" : nil)) do
      td(class: "font-medium") do
        a(href: admin_league_path(league), class: "link link-hover") { league.name }
        if league.private?
          span(class: "badge badge-sm badge-ghost ml-2") { "private" }
        end
      end
      td(class: "text-sm") { ls&.season&.label || "-" }
      td { ls ? render_status(ls.status) : plain("-") }
      td(class: "text-sm") { owner_label(participants) }
      td { render_user_badge(user_count, participants.size) }
      td(class: "text-sm whitespace-nowrap") { league.created_at.strftime("%Y-%m-%d") }
      td(class: "flex flex-wrap gap-1 justify-end") do
        a(href: edit_admin_league_path(league), class: "btn btn-ghost btn-xs",
          title: "Edit", aria_label: "Edit") do
          render Views::Components::Icon.new(:pencil_square)
        end
        button_to admin_league_path(league),
          method: :delete,
          form: {class: "inline", data: {turbo_confirm: "Delete #{league.name}? This removes every season's participants and draft picks."}},
          class: "btn btn-error btn-xs",
          title: "Delete", aria: {label: "Delete"} do
          render Views::Components::Icon.new(:trash)
        end
      end
    end
  end

  def render_status(status)
    color = {
      "draft_pending" => "badge-ghost",
      "drafting" => "badge-warning",
      "in_season" => "badge-success",
      "completed" => "badge-info"
    }[status]
    span(class: "badge badge-sm #{color}") { status }
  end

  def render_user_badge(user_count, total)
    if total.zero?
      span(class: "opacity-50") { "-" }
    elsif user_count.zero?
      span(class: "badge badge-sm badge-warning") { "anonymous" }
    else
      color = (user_count == total) ? "badge-success" : "badge-info"
      span(class: "badge badge-sm #{color}") { "#{user_count}/#{total} signed up" }
    end
  end

  def owner_label(participants)
    owner = participants.find { |p| p.is_owner }
    return span(class: "opacity-50") { "-" } unless owner
    owner.user&.email_address || owner.display_name
  end
end
