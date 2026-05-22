# frozen_string_literal: true

# Mission Control's HTTP basic auth is redundant - the engine is mounted under
# /admin and inherits Admin::BaseController, which already enforces sign-in +
# admin role.
MissionControl::Jobs.base_controller_class = "Admin::BaseController"
MissionControl::Jobs.http_basic_auth_enabled = false
