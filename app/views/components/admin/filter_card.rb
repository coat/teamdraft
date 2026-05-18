# frozen_string_literal: true

# Wraps a GET form_with in a daisyUI card. Caller provides the visible filter
# fields via the block (receiving the form builder); we auto-render hidden
# sort/dir fields (to preserve the current sort across filter submits) and the
# Filter/Clear buttons. Caller's `query` must respond to `sort_column` and
# `sort_dir` (the ListQuery pattern).
class Views::Components::Admin::FilterCard < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(url:, query:, clear_path: nil)
    @url = url
    @query = query
    @clear_path = clear_path || url
  end

  def view_template(&block)
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body p-4") do
        form_with(url: @url, method: :get, scope: nil, local: true,
          class: "flex flex-wrap items-end gap-3") do |form|
          yield(form)
          form.hidden_field :sort, value: @query.sort_column
          form.hidden_field :dir, value: @query.sort_dir
          div(class: "flex gap-2") do
            form.submit "Filter", class: "btn btn-primary"
            a(href: @clear_path, class: "btn btn-ghost") { "Clear" }
          end
        end
      end
    end
  end
end
