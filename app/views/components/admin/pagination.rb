# frozen_string_literal: true

# DaisyUI-styled pagination using pagy's series. Renders nothing when there's
# only a single page. Each link preserves the current request's query params
# (filters/sort) so paging never drops them.
class Views::Components::Admin::Pagination < Views::Base
  include Phlex::Rails::Helpers::Request

  def initialize(pagy:)
    @pagy = pagy
  end

  def view_template
    return if @pagy.last <= 1

    nav(class: "flex justify-center mt-4", aria_label: "Pagination") do
      div(class: "join") do
        render_step(:chevron_left, @pagy.previous, "Previous page")
        # `series` is protected in pagy 43+; call it directly since we render
        # fully custom markup rather than using pagy's built-in series_nav.
        @pagy.__send__(:series).each { |item| render_item(item) }
        render_step(:chevron_right, @pagy.next, "Next page")
      end
    end
  end

  private

  def render_item(item)
    case item
    when Integer
      a(href: page_href(item), class: "join-item btn btn-sm") { item.to_s }
    when String
      # The current page is emitted as a string by pagy.series.
      span(class: "join-item btn btn-sm btn-active", aria_current: "page") { item }
    when :gap
      span(class: "join-item btn btn-sm btn-disabled") { "…" }
    end
  end

  def render_step(icon, target_page, label)
    if target_page
      a(href: page_href(target_page), class: "join-item btn btn-sm", aria_label: label) do
        render Views::Components::Icon.new(icon)
      end
    else
      span(class: "join-item btn btn-sm btn-disabled", aria_disabled: "true", aria_label: label) do
        render Views::Components::Icon.new(icon)
      end
    end
  end

  def page_href(page)
    qs = request.query_parameters.merge(page: page).compact_blank
    "#{request.path}?#{qs.to_query}"
  end
end
