# frozen_string_literal: true

# Phlex helper adapter so views can call `current_user` directly without
# going through the deprecated `helpers` proxy.
module Components::Helpers::CurrentUser
  extend Phlex::Rails::HelperMacros

  register_value_helper def current_user(...) = nil
end
