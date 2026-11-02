# The gem only loads in development and test (D23).
if defined?(Rswag::Api)
  Rswag::Api.configure do |c|
    c.openapi_root = Rails.root.join("swagger").to_s
  end
end
