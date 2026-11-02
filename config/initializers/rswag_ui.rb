# The gem only loads in development and test (D23).
if defined?(Rswag::Ui)
  Rswag::Ui.configure do |c|
    c.openapi_endpoint "/api-docs/v1/swagger.yaml", "Library API v1"
  end
end
