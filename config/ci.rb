# Run using bin/ci

CI.run do
  step "Tests: RSpec", "bin/rspec"

  step "Docs: OpenAPI file is current", "cp swagger/v1/swagger.yaml tmp/swagger.before.yaml && bundle exec rake rswag:specs:swaggerize && diff -u tmp/swagger.before.yaml swagger/v1/swagger.yaml"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Gem audit", "bin/bundler-audit check --update"
end
