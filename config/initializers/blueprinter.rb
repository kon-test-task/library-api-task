# The default JSON generator writes times as "2026-10-13 12:44:51 UTC". The Rails encoder writes ISO 8601.
Blueprinter.configure do |config|
  config.generator = ActiveSupport::JSON
  config.method = :encode
end
