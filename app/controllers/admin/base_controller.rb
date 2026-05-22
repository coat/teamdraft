# frozen_string_literal: true

# All admin controllers inherit from this. Stays separate from
# ApplicationController so admin-specific concerns (logging, layout, csrf
# nuances) can grow here without bleeding into the public site.
class Admin::BaseController < ApplicationController
  include Pagy::Method

  before_action :require_authentication
  before_action :require_admin

  private

  def require_admin
    return if current_user&.admin? && !current_user.disabled?
    redirect_to main_app.root_path, alert: "Admin access required."
  end
end
