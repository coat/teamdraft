# frozen_string_literal: true

require "axe-rspec"
require "capybara/cuprite"

# axe-core-api only speaks Selenium. Two bridges make it work with Cuprite:
#
# 1. legacy_mode: the default runPartial flow drives Selenium-specific APIs
#    (timeouts.page_load, window handles). Legacy mode runs axe.run in-page,
#    which is all Cuprite can do - and all we need (no cross-origin frames).
# 2. execute_async_script: Selenium's name for what Capybara drivers call
#    evaluate_async_script; both wrap the script in a function that receives
#    `arguments` with a completion callback last, so a rename suffices.
Axe::Configuration.instance.legacy_mode = true

Capybara::Cuprite::Browser.class_eval do
  # axe unwraps the Capybara session down to this browser object before
  # calling. Ferrum's evaluate_async has the same contract (script body,
  # completion callback appended to `arguments`), just a different name.
  # 30s wait: axe.run on table-heavy pages outlasts Ferrum's 5s default.
  def execute_async_script(script, *args)
    evaluate_async(script, 30, *args)
  end
end
