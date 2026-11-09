source "https://rubygems.org"

ruby "4.0.9"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "8.1.4.1"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Background jobs backed by Redis
gem "sidekiq", "~> 8.1"
# Recurring cron jobs for Sidekiq
gem "sidekiq-cron", "~> 2.4"
# Catch unsafe migrations before they run
gem "strong_migrations", "~> 2.8"
# JSON views for the API
gem "blueprinter", "~> 1.2"
# Offset pagination for the book list
gem "pagy", "~> 43.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Test framework
  gem "rspec-rails", "~> 8.0"

  # Test data
  gem "factory_bot_rails", "~> 6.5"

  # Request specs that generate the OpenAPI file
  gem "rswag-specs", "~> 2.17"

  # Serve the OpenAPI file at /api-docs
  gem "rswag-api", "~> 2.17"

  # Scalar API reference at /docs, which reads that file
  gem "scalar_ruby", "~> 2.0"

  # Detect N+1 queries and unused eager loading
  gem "bullet", "~> 8.3"
end

group :development do
  # View delivered emails in the browser
  gem "letter_opener_web", "~> 3.0"
end

group :test do
  # One-line model specs
  gem "shoulda-matchers", "~> 8.0"

  # Check request spec responses against the committed OpenAPI file
  gem "committee-rails", "~> 0.10"
end
