# Run using bin/ci

CI.run do
  step "Tests: RSpec", "bin/rspec"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Gem audit", "bin/bundler-audit check --update"
end
