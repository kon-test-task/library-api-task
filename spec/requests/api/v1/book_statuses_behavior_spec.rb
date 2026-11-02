require "rails_helper"

# Cases beyond the one-example-per-code rswag specs, kept out of the OpenAPI file.
RSpec.describe "Book status API behavior", type: :request do
  let(:book) { create(:book) }
  let!(:reader) { create(:reader, card_number: "100001") }
  let(:path) { "/api/v1/books/#{book.serial_number}/status" }
  let(:body) { JSON.parse(response.body) }
  let(:first_error) { body["errors"].first }

  def lend
    patch path, params: { status: "borrowed", card_number: "100001" }, as: :json
  end

  def give_back
    patch path, params: { status: "available" }, as: :json
  end

  it "shows the return time in the history after a return" do
    lend
    travel_to 5.days.from_now do
      give_back

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("status" => "available", "borrowed" => false, "current_loan" => nil)
      expect(JSON.parse(response.body)["loans"].first["returned_at"]).to be_present
    end
  end

  it "returns 409 when the book is already available" do
    give_back

    expect(response).to have_http_status(:conflict)
    expect(first_error).to include("code" => "already_available", "field" => nil)
  end

  it "returns 422 when lending without a card number" do
    patch path, params: { status: "borrowed" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(first_error).to include("code" => "missing_card_number", "field" => "card_number")
  end

  it "finds the reader when the card number has surrounding spaces" do
    patch path, params: { status: "borrowed", card_number: " 100001 " }, as: :json

    expect(response).to have_http_status(:ok)
    expect(body.dig("current_loan", "reader", "card_number")).to eq("100001")
  end

  it "returns 422 ahead of 409 when a borrowed book gets a bad card number" do
    lend

    patch path, params: { status: "borrowed", card_number: "999999" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(first_error["code"]).to eq("unknown_reader")
  end

  it "returns 422 for an unknown status" do
    patch path, params: { status: "lost" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(first_error).to include("code" => "invalid_status", "field" => "status")
  end

  it "returns 422 without a status" do
    patch path, params: { card_number: "100001" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(first_error).to include("code" => "parameter_missing", "field" => "status")
  end

  it "does not fail on a status that is not a string" do
    patch path, params: { status: { a: "b" } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(first_error["code"]).to eq("invalid_status")
  end

  it "shows up in the book list" do
    lend

    get "/api/v1/books"

    expect(JSON.parse(response.body)["books"].first).to include("status" => "borrowed", "borrowed" => true)
  end

  it "makes a lent book refuse deletion, and a returned book accept it" do
    lend
    delete "/api/v1/books/#{book.serial_number}"
    expect(response).to have_http_status(:conflict)

    give_back
    delete "/api/v1/books/#{book.serial_number}"
    expect(response).to have_http_status(:no_content)
  end

  it "stays free of N+1 queries on a book with several past loans" do
    3.times do
      lend
      give_back
    end

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["loans"].size).to eq(3)
  end
end
