# frozen_string_literal: true

class Views::Components::Breadcrumbs < Views::Base
  def initialize(trail:)
    @trail = trail
  end

  def view_template
    div(class: "text-sm breadcrumbs") do
      ul do
        @trail.each do |label, href|
          li { href ? a(href: href) { label } : span { label } }
        end
      end
    end
  end
end
