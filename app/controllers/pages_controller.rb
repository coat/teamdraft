# frozen_string_literal: true

# Static-ish marketing pages (About, Privacy, etc.). Each action just renders
# its Phlex view. To add another page: define an action here, add a route,
# and create app/views/pages/<name>.rb.
class PagesController < ApplicationController
  def about
    sports = Sport.active.order(:name)
    active = sports.find { |s| s.key == params[:sport] } || sports.first
    render Views::Pages::About.new(sports: sports, active_sport: active)
  end

  def privacy
    render Views::Pages::Privacy.new
  end
end
