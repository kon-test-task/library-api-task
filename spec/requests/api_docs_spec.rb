require "rails_helper"

RSpec.describe "API docs", type: :request do
  it "serves the Scalar reference with a pinned script, reading the OpenAPI file" do
    get "/docs"

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(%r{@scalar/api-reference@\d+\.\d+\.\d+})
    expect(response.body).to include("/api-docs/v1/swagger.yaml")
  end

  it "turns off Scalar's product bar and AI button" do
    get "/docs"

    expect(response.body).to include('"showDeveloperTools":"never"', '"agent":{"disabled":true}')
  end

  it "redirects /api-docs to the Scalar reference" do
    get "/api-docs"

    expect(response).to redirect_to("/docs")
  end

  it "serves the OpenAPI file with every operation" do
    get "/api-docs/v1/swagger.yaml"

    expect(response).to have_http_status(:ok)

    paths = YAML.safe_load(response.body).fetch("paths")

    expect(paths.transform_values(&:keys)).to eq(
      "/api/v1/books" => %w[get post],
      "/api/v1/books/{serial_number}" => %w[get delete],
      "/api/v1/books/{serial_number}/status" => %w[patch],
      "/api/v1/readers/{card_number}/books" => %w[get]
    )
  end
end
