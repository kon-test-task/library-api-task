require "rails_helper"

RSpec.describe "API docs", type: :request do
  it "serves Swagger UI" do
    get "/api-docs/index.html"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/api-docs/v1/swagger.yaml")
  end

  it "serves the OpenAPI file with all five operations" do
    get "/api-docs/v1/swagger.yaml"

    expect(response).to have_http_status(:ok)

    paths = YAML.safe_load(response.body).fetch("paths")

    expect(paths.transform_values(&:keys)).to eq(
      "/api/v1/books" => %w[get post],
      "/api/v1/books/{serial_number}" => %w[get delete],
      "/api/v1/books/{serial_number}/status" => %w[patch]
    )
  end
end
