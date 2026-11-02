require "rails_helper"

# Cases beyond the rswag specs, kept out of the OpenAPI file.
RSpec.describe "Reader books API behavior", type: :request do
  let(:reader) { create(:reader, card_number: "004219") }
  let(:body) { response.parsed_body }
  let(:serials) { body["loans"].map { |loan| loan.dig("book", "serial_number") } }

  before do
    create(:borrowing, reader: reader, book: create(:book, serial_number: "000001"), borrowed_at: 3.days.ago)
    create(:borrowing, reader: reader, book: create(:book, serial_number: "000002", author_names: [ "Andrew Hunt", "David Thomas" ]), borrowed_at: 1.day.ago)
    create(:borrowing, :returned, reader: reader, book: create(:book, serial_number: "000003"), borrowed_at: 9.days.ago, returned_at: 8.days.ago)
    create(:borrowing, book: create(:book, serial_number: "000004"))
  end

  it "returns open loans newest first, and only this reader's" do
    get "/api/v1/readers/004219/books"

    expect(serials).to eq(%w[000002 000001])
    expect(body["meta"]["count"]).to eq(2)
  end

  it "finds a card number with leading zeros" do
    get "/api/v1/readers/004219/books"

    expect(body.dig("reader", "card_number")).to eq("004219")
  end

  it "adds returned loans with include_returned=true" do
    get "/api/v1/readers/004219/books", params: { include_returned: "true" }

    expect(serials).to eq(%w[000002 000001 000003])
    expect(body["loans"].last["returned_at"]).to be_present
    expect(body["meta"]["count"]).to eq(3)
  end

  [ "false", "", "yes" ].each do |value|
    it "keeps to open loans for include_returned=#{value.inspect}" do
      get "/api/v1/readers/004219/books", params: { include_returned: value }

      expect(serials).to eq(%w[000002 000001])
    end
  end

  it "shows the joined author string in display order" do
    get "/api/v1/readers/004219/books"

    expect(body["loans"].first["book"]).to eq(
      "serial_number" => "000002", "title" => Book.find_by!(serial_number: "000002").title, "author" => "Andrew Hunt, David Thomas"
    )
  end

  it "paginates" do
    get "/api/v1/readers/004219/books", params: { page: 2, limit: 1 }

    expect(serials).to eq(%w[000001])
    expect(body["meta"]).to include("count" => 2, "page" => 2, "limit" => 1, "last" => 2, "previous" => 1)
  end

  it "caps the limit at 100" do
    get "/api/v1/readers/004219/books", params: { limit: 1000 }

    expect(body["meta"]["limit"]).to eq(100)
  end

  it "returns an empty list for a reader with no open loans" do
    empty = create(:reader, card_number: "100009")

    get "/api/v1/readers/#{empty.card_number}/books"

    expect(response).to have_http_status(:ok)
    expect(body["loans"]).to eq([])
    expect(body["meta"]["count"]).to eq(0)
  end

  it "loads many loans without an N+1 query" do
    3.times { create(:borrowing, reader: reader, book: create(:book, author_names: [ "Sandi Metz", "Katrina Owen" ])) }

    get "/api/v1/readers/004219/books"

    expect(response).to have_http_status(:ok)
    expect(serials.size).to eq(5)
  end
end
