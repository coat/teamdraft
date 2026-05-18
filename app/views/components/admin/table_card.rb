# frozen_string_literal: true

# Lightweight shell for admin tables: card + horizontal scroll wrapper + the
# standard daisyUI table classes. Caller renders thead/tbody so per-resource
# layouts stay flexible.
class Views::Components::Admin::TableCard < Views::Base
  def view_template(&)
    div(class: "card bg-base-100 shadow") do
      div(class: "overflow-x-auto") do
        table(class: "table table-sm table-zebra") { yield }
      end
    end
  end
end
