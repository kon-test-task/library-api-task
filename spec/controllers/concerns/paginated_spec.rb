require "rails_helper"

RSpec.describe Paginated, type: :controller do
  controller(ApplicationController) do
    include Paginated

    def index
      records, meta = paginate(Book.order(:serial_number))

      render json: { serials: records.map(&:serial_number), meta: meta }
    end
  end

  let(:body) { JSON.parse(response.body) }

  before { 3.times { create(:book) } }

  it "defaults to the first page of 20" do
    get :index

    expect(body["meta"]).to eq("count" => 3, "page" => 1, "limit" => 20, "last" => 1)
  end

  it "returns the requested page with previous and next" do
    get :index, params: { page: 2, limit: 1 }

    expect(body["serials"].size).to eq(1)
    expect(body["meta"]).to eq("count" => 3, "page" => 2, "limit" => 1, "last" => 3, "previous" => 1, "next" => 3)
  end

  it "caps the limit at MAX_LIMIT" do
    get :index, params: { limit: Paginated::MAX_LIMIT + 1 }

    expect(body["meta"]["limit"]).to eq(Paginated::MAX_LIMIT)
  end

  it "renders a negative limit as 422 and names the field" do
    get :index, params: { limit: -5 }

    expect(response).to have_http_status(:unprocessable_content)
    expect(body["errors"]).to eq([ { "code" => "invalid_pagination", "message" => "limit must be at least 1", "field" => "limit" } ])
  end
end
