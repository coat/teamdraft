# frozen_string_literal: true

# Titled card for "related resources" sections on show pages. Caller provides
# the list contents (typically a `ul.menu` of links). Used to keep cross-
# resource linking visually consistent across admin show pages.
class Views::Components::Admin::RelatedPanel < Views::Base
  def initialize(title:)
    @title = title
  end

  def view_template(&)
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title text-base") { @title }
        yield
      end
    end
  end
end
