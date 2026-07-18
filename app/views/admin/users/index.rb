# frozen_string_literal: true

class Views::Admin::Users::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(query:, users:, pagy:)
    @query = query
    @users = users
    @pagy = pagy
  end

  def view_template
    render Views::Layouts::Admin.new(title: "Users", section: :users, breadcrumbs: [["Users", nil]]) do
      render Views::Components::Admin::PageHeader.new(
        title: "Users",
        subtitle: "Manage registered accounts. Grant or revoke admin access, or disable an account to block sign-in."
      )
      render_filter_card
      render_table_card
      render Views::Components::Admin::Pagination.new(pagy: @pagy)
    end
  end

  private

  def render_filter_card
    render Views::Components::Admin::FilterCard.new(url: admin_users_path, query: @query) do |form|
      div(class: "space-y-1") do
        form.label :q, "Search", class: "label label-text text-xs uppercase tracking-wide"
        form.text_field :q, value: @query.search_term, placeholder: "Email…",
          class: "input input-bordered w-64"
      end
      div(class: "space-y-1") do
        form.label :role, "Role", class: "label label-text text-xs uppercase tracking-wide"
        form.select :role,
          [["Any role", ""], ["Admin", "admin"], ["Non-admin", "non_admin"]],
          {selected: @query.role},
          class: "select select-bordered"
      end
      div(class: "space-y-1") do
        form.label :status, "Status", class: "label label-text text-xs uppercase tracking-wide"
        form.select :status,
          [["Any status", ""], ["Active", "active"], ["Disabled", "disabled"]],
          {selected: @query.status},
          class: "select select-bordered"
      end
    end
  end

  def render_table_card
    render Views::Components::Admin::TableCard.new do
      thead do
        tr do
          render Views::Components::SortableHeader.new(query: @query, column: "email_address", label: "Email", path: admin_users_path)
          th(scope: "col") { "Role" }
          th(scope: "col") { "Status" }
          render Views::Components::SortableHeader.new(query: @query, column: "created_at", label: "Created", path: admin_users_path)
          th(scope: "col") { span(class: "sr-only") { "Actions" } }
        end
      end
      tbody do
        if @users.empty?
          tr do
            td(colspan: "5") do
              div(class: "alert alert-info my-2") { span { "No users match these filters." } }
            end
          end
        else
          @users.each { |user| render_row(user) }
        end
      end
    end
  end

  def render_row(user)
    tr(class: (user.disabled? ? "opacity-70" : nil)) do
      td(class: "font-medium") do
        a(href: admin_user_path(user), class: "link link-hover") { user.email_address }
      end
      td do
        if user.admin?
          span(class: "badge badge-sm badge-primary") { "admin" }
        else
          span(class: "opacity-50 text-xs") { "-" }
        end
      end
      td do
        if user.disabled?
          span(class: "badge badge-sm badge-warning") { "disabled" }
        else
          span(class: "badge badge-sm badge-success") { "active" }
        end
      end
      td(class: "text-sm whitespace-nowrap") { user.created_at.strftime("%Y-%m-%d") }
      td(class: "text-right") do
        a(href: admin_user_path(user), class: "btn btn-ghost btn-xs") { "View" }
      end
    end
  end
end
