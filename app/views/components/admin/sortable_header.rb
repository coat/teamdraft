# frozen_string_literal: true

# A <th> with a link that toggles sort direction for the given column.
# Reads current sort state from a ListQuery-like object that responds to
# `sort_column`, `sort_dir`, and `to_url_params(overrides)`.
class Views::Components::Admin::SortableHeader < Views::Base
  def initialize(query:, column:, label:, path:)
    @query = query
    @column = column.to_s
    @label = label
    @path = path
  end

  def view_template
    th do
      a(href: link_href, class: "link link-hover inline-flex items-center gap-1") do
        plain @label
        span(class: "text-xs opacity-60") { arrow }
      end
    end
  end

  private

  def active? = @query.sort_column == @column

  def next_dir
    return "asc" unless active?
    (@query.sort_dir == "asc") ? "desc" : "asc"
  end

  def arrow
    return "↕" unless active?
    (@query.sort_dir == "asc") ? "▲" : "▼"
  end

  def link_href
    params = @query.to_url_params(sort: @column, dir: next_dir)
    "#{@path}?#{params.to_query}"
  end
end
