# frozen_string_literal: true

# "Skip to content" link for keyboard users: visually hidden until
# focused, jumps past the header/nav to the #main-content landmark
# (which carries tabindex: -1 so it can receive focus).
class Views::Components::SkipLink < Views::Base
  def view_template
    a(
      href: "#main-content",
      class: "sr-only focus:not-sr-only focus:absolute focus:top-2 focus:left-2 focus:z-50 btn btn-primary btn-sm"
    ) { "Skip to content" }
  end
end
