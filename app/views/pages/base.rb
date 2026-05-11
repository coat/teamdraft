# frozen_string_literal: true

# Shared chrome for static pages — card-on-base-100 inside the app layout.
# Subclasses override `page_title` and `body` to fill in content.
class Views::Pages::Base < Views::Base
  def view_template
    render Views::Layouts::Application.new(title: page_title) do
      main(class: "py-8") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body prose max-w-none") do
            h1 { page_title }
            body
          end
        end
      end
    end
  end

  def page_title = self.class.name.demodulize
  def body = nil
end
