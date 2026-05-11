# frozen_string_literal: true

require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1400, 900],
    headless: true,
    process_timeout: 20,
    timeout: 10
  )
end

Capybara.javascript_driver = :cuprite
Capybara.default_driver = :rack_test
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :rack_test }
  config.before(:each, type: :system, js: true) { driven_by :cuprite }
end
