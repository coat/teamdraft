# frozen_string_literal: true

require "pagy"

# Default page size; override per-call via `pagy(scope, limit: N)`.
Pagy::OPTIONS[:limit] = 25
# Number of page links shown around the current page in the series.
Pagy::OPTIONS[:slots] = 5
