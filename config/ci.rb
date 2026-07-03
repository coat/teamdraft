# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Standard", "bundle exec standardrb"
  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: RSpec", "bundle exec rspec"
  # db:test:prepare restores a pristine schema afterwards - leftover seed
  # rows (e.g. installed sports) collide with factory-created records on
  # the next RSpec run.
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant db:test:prepare"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
