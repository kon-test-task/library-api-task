require "rails_helper"

RSpec.describe ErrorsController, type: :controller do
  describe "#route_not_found" do
    it "renders 404 in the API's error format" do
      get :route_not_found, params: { unmatched: "nope" }

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq(
        "errors" => [ { "code" => "route_not_found", "message" => "Route not found", "field" => nil } ]
      )
    end

    it "answers every HTTP method" do
      post :route_not_found, params: { unmatched: "nope" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
