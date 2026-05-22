# frozen_string_literal: true

class Views::Rankings::SportsIndex < Views::Base
  def initialize(sports:)
    @sports = sports
  end

  def view_template
    render Views::Layouts::Application.new(title: "My Rankings") do
      main(class: "py-6") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "My Rankings" }
            p(class: "text-sm text-base-content/70") do
              "Customize the team order used for your auto-picks when your draft clock expires."
            end
            ul(class: "list bg-base-100 rounded-box border border-base-300 mt-4") do
              @sports.each do |sport|
                li(class: "list-row flex items-center gap-3 px-3 py-2") do
                  span(class: "font-medium grow") { sport.name }
                  a(href: sport_rankings_path(sport.key), class: "btn btn-sm inline-flex items-center gap-1") do
                    render Views::Components::Icon.new(:pencil_square)
                    plain "Edit"
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
