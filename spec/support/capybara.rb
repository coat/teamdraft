# frozen_string_literal: true

require "capybara/rspec"
require "capybara/cuprite"

Capybara.default_driver = :rack_test
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :rack_test }
  # Options must go through driven_by: it re-registers :cuprite on every call,
  # clobbering any Capybara.register_driver(:cuprite) done up front.
  config.before(:each, type: :system, js: true) do
    driven_by :cuprite, screen_size: [1400, 900],
      options: {headless: true, process_timeout: 20, timeout: 10}
  end
end
