# frozen_string_literal: true

require "webmock/rspec"
require "httpx/adapters/webmock"

WebMock.disable_net_connect!(allow_localhost: true)
