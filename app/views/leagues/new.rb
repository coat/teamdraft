# frozen_string_literal: true

class Views::Leagues::New < Views::Base
  def initialize(league:, seasons:, errors: [])
    @league = league
    @seasons = seasons
    @errors = errors
  end

  def view_template
    render Views::Layouts::Application.new(title: "Start a Team Draft") do
      main(class: "py-8") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body") do
            h1(class: "card-title text-3xl") { "Start a Team Draft" }
            p(class: "text-base-content/70") { "Two friends. One season. Pick your teams." }

            render Views::Leagues::Form.new(league: @league, seasons: @seasons, errors: @errors)
          end
        end
      end
    end
  end
end
