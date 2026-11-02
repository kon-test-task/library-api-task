# The gem only loads in development and test (D23).
if defined?(Scalar)
  Scalar.setup do |config|
    # A pinned script, so the page does not change on the reviewer's machine.
    config.library_url = "https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.76.4"
    config.page_title = "Library API"
    # Scalar shows its product bar and AI button on localhost unless told not to.
    config.configuration = {
      url: "/api-docs/v1/swagger.yaml",
      showDeveloperTools: "never",
      agent: { disabled: true }
    }
  end
end
