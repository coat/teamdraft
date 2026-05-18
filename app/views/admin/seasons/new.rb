# frozen_string_literal: true

class Views::Admin::Seasons::New < Views::Base
  def initialize(season:, sports:)
    @season = season
    @sports = sports
  end

  def view_template
    render Views::Layouts::Admin.new(
      title: "New season",
      section: :seasons,
      breadcrumbs: [["Seasons", admin_seasons_path], ["New", nil]]
    ) do
      render Views::Components::Admin::PageHeader.new(title: "New season")
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body") do
          render Views::Admin::Seasons::Form.new(
            season: @season, sports: @sports,
            url: admin_seasons_path, method: :post
          )
        end
      end
    end
  end
end
