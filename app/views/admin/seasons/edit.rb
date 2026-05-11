# frozen_string_literal: true

class Views::Admin::Seasons::Edit < Views::Base
  def initialize(season:, sports:)
    @season = season
    @sports = sports
  end

  def view_template
    render Views::Layouts::Application.new(title: "Edit season · Admin") do
      main(class: "py-6") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Edit #{@season.label}" }
            render Views::Admin::Seasons::Form.new(
              season: @season, sports: @sports,
              url: admin_season_path(@season), method: :patch
            )
          end
        end
      end
    end
  end
end
