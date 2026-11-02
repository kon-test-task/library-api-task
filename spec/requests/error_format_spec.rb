require "rails_helper"

# Failures outside the documented operations still use the one error format.
RSpec.describe "Error format", type: :request do
  let(:first_error) { response.parsed_body["errors"].first }

  [
    [ :get, "/api/v1/nope" ],
    [ :get, "/nope" ],
    [ :get, "/nope.json" ],
    [ :post, "/api/v1/books/000101" ]
  ].each do |verb, path|
    it "returns the error format for #{verb.upcase} #{path}, which has no route", :undocumented do
      public_send(verb, path)

      expect(response).to have_http_status(:not_found)
      expect(first_error).to eq("code" => "route_not_found", "message" => "Route not found", "field" => nil)
    end
  end

  it "leaves the routes above the catch-all alone" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end

  describe "an unexpected failure" do
    before { allow(Book).to receive(:includes).and_raise(ArgumentError, "secret detail") }

    it "returns the error format without the exception message" do
      get "/api/v1/books"

      expect(response).to have_http_status(:internal_server_error)
      expect(first_error).to eq("code" => "internal_error", "message" => "Something went wrong", "field" => nil)
      expect(response.body).not_to include("secret detail")
    end

    it "logs the exception" do
      allow(Rails.logger).to receive(:error)

      get "/api/v1/books"

      expect(Rails.logger).to have_received(:error).with(a_string_including("ArgumentError: secret detail"))
    end
  end

  [
    "/api/v1/books?page=%E0",
    "/api/v1/books?a=1&a[b]=2"
  ].each do |path|
    it "returns 400 in the error format for #{path}" do
      get path

      expect(response).to have_http_status(:bad_request)
      expect(first_error).to eq("code" => "bad_request", "message" => "Request parameters could not be read", "field" => nil)
    end
  end
end
