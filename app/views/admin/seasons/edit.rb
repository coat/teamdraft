# frozen_string_literal: true

class Views::Admin::Seasons::Edit < Views::Base
  def initialize(season:, sports:)
    @season = season
    @sports = sports
  end

  def view_template
    render Views::Layouts::Admin.new(
      title: "Edit #{@season.label}",
      section: :seasons,
      breadcrumbs: [
        ["Seasons", admin_seasons_path],
        [@season.label, admin_season_path(@season)],
        ["Edit", nil]
      ]
    ) do
      render Views::Components::Admin::PageHeader.new(title: "Edit #{@season.label}")
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body") do
          render Views::Admin::Seasons::Form.new(
            season: @season, sports: @sports,
            url: admin_season_path(@season), method: :patch
          )
        end
      end
    end
  end
end
