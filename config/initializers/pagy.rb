# frozen_string_literal: true

require "pagy"

# Default page size; override per-call via `pagy(scope, items: N)`.
Pagy::DEFAULT[:items] = 25
# Number of page links shown around the current page in pagy_nav.
Pagy::DEFAULT[:size] = 5
