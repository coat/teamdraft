# frozen_string_literal: true

class Views::Components::Admin::Breadcrumbs < Views::Base
  def initialize(trail:)
    @trail = trail || []
  end

  def view_template
    return if @trail.empty?
    div(class: "text-sm breadcrumbs") do
      ul do
        li { a(href: admin_root_path) { "Admin" } }
        @trail.each do |label, href|
          li { href ? a(href: href) { label } : span { label } }
        end
      end
    end
  end
end
