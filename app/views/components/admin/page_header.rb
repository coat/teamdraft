# frozen_string_literal: true

class Views::Components::Admin::PageHeader < Views::Base
  def initialize(title:, subtitle: nil)
    @title = title
    @subtitle = subtitle
  end

  def view_template(&block)
    div(class: "flex flex-wrap items-start justify-between gap-4") do
      div do
        h1(class: "text-3xl font-bold") { @title }
        if @subtitle
          p(class: "text-sm text-base-content/70 mt-1") { @subtitle }
        end
      end
      if block
        div(class: "flex flex-wrap gap-2 items-center") { yield }
      end
    end
  end
end
