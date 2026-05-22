# frozen_string_literal: true

# A <th> with a link that toggles sort direction for the given column.
# Reads current sort state from a ListQuery-like object that responds to
# `sort_column`, `sort_dir`, and `to_url_params(overrides)`. Used by both
# the admin index pages and the in-app team directory; lives outside the
# Admin namespace because nothing about it is admin-specific.
class Views::Components::SortableHeader < Views::Base
  def initialize(query:, column:, label:, path:, class_name: nil)
    @query = query
    @column = column.to_s
    @label = label
    @path = path
    @class_name = class_name
  end

  def view_template
    th(class: @class_name) do
      # data-turbo-action="advance" pushes the new URL to the address bar
      # when this link updates a surrounding turbo-frame. Without it, the
      # frame updates but `window.location.href` stays stale - so a
      # subsequent Turbo refresh (e.g. from a Cable broadcast) re-fetches
      # the old URL and the user loses their sort state.
      a(href: link_href, class: "link link-hover inline-flex items-center gap-1",
        data: {turbo_action: "advance"}) do
        plain @label
        span(class: "opacity-60") { render Views::Components::Icon.new(arrow_name, class_name: "size-3") }
      end
    end
  end

  private

  def active? = @query.sort_column == @column

  def next_dir
    return "asc" unless active?
    (@query.sort_dir == "asc") ? "desc" : "asc"
  end

  def arrow_name
    return :chevron_up_down unless active?
    (@query.sort_dir == "asc") ? :chevron_up : :chevron_down
  end

  def link_href
    params = @query.to_url_params(sort: @column, dir: next_dir)
    "#{@path}?#{params.to_query}"
  end
end
