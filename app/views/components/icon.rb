# frozen_string_literal: true

# Thin wrapper around PhlexIcons::Hero so call sites read
# `render Icon.new(:chevron_up)` instead of repeating the gem namespace and
# variant on every line. Heroicons ship in :outline (24px stroke) and :solid
# (24px filled) - sizing is via Tailwind class (default `size-4`).
class Views::Components::Icon < Views::Base
  def initialize(name, variant: :outline, class_name: "size-4", **attrs)
    @name = name
    @variant = variant
    @class_name = class_name
    @attrs = attrs
  end

  def view_template
    klass = PhlexIcons::Hero.const_get(@name.to_s.camelize)
    render klass.new(variant: @variant, class: @class_name, **@attrs)
  end
end
