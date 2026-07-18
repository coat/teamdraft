# frozen_string_literal: true

# Three-bar menu glyph used in mobile nav toggles across the front-end and
# admin layouts.
class Views::Components::HamburgerIcon < Views::Base
  def initialize(class_name: "h-5 w-5")
    @class_name = class_name
  end

  def view_template
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      class: @class_name,
      fill: "none",
      viewBox: "0 0 24 24",
      stroke: "currentColor",
      aria_hidden: "true"
    ) do |s|
      s.path(
        stroke_linecap: "round",
        stroke_linejoin: "round",
        stroke_width: "2",
        d: "M4 6h16M4 12h16M4 18h16"
      )
    end
  end
end
