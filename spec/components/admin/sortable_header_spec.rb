# frozen_string_literal: true

require "rails_helper"

RSpec.describe Views::Components::Admin::SortableHeader, type: :view do
  it "renders a link that toggles direction when the column is active asc" do
    query = Admin::Leagues::ListQuery.new(sort: "name", dir: "asc")

    html = Views::Components::Admin::SortableHeader.new(
      query: query, column: "name", label: "Name", path: "/admin/leagues"
    ).call

    expect(html).to include("dir=desc")
    expect(html).to include("sort=name")
    expect(html).to include("▲")
  end

  it "renders an asc link when the column is not the current sort" do
    query = Admin::Leagues::ListQuery.new(sort: "name", dir: "asc")

    html = Views::Components::Admin::SortableHeader.new(
      query: query, column: "created_at", label: "Created", path: "/admin/leagues"
    ).call

    expect(html).to include("dir=asc")
    expect(html).to include("sort=created_at")
    expect(html).to include("↕")
  end
end
