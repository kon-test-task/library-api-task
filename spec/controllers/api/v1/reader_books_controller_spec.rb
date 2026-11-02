require "rails_helper"

RSpec.describe Api::V1::ReaderBooksController, type: :controller do
  let(:reader) { create(:reader) }
  let(:body) { JSON.parse(response.body) }
  let(:serials) { body["loans"].map { |loan| loan.dig("book", "serial_number") } }

  describe "GET #index" do
    it "renders the reader, the loans and the metadata" do
      create(:borrowing, reader: reader)

      get :index, params: { reader_card_number: reader.card_number }

      expect(response).to have_http_status(:ok)
      expect(body.keys).to contain_exactly("reader", "loans", "meta")
      expect(body["reader"]).to eq(JSON.parse(ReaderBlueprint.render(reader)))
    end

    it "orders loans borrowed at the same moment by the newest record" do
      freeze_time

      first = create(:borrowing, reader: reader)
      second = create(:borrowing, reader: reader)

      get :index, params: { reader_card_number: reader.card_number }

      expect(serials).to eq([ second.book.serial_number, first.book.serial_number ])
    end

    it "leaves out returned loans by default" do
      create(:borrowing, :returned, reader: reader)

      get :index, params: { reader_card_number: reader.card_number }

      expect(body["loans"]).to be_empty
    end

    it "adds returned loans only for the exact value true" do
      loan = create(:borrowing, :returned, reader: reader)

      get :index, params: { reader_card_number: reader.card_number, include_returned: "true" }

      expect(serials).to eq([ loan.book.serial_number ])
    end

    it "does not treat another truthy value as true" do
      create(:borrowing, :returned, reader: reader)

      get :index, params: { reader_card_number: reader.card_number, include_returned: "1" }

      expect(body["loans"]).to be_empty
    end

    it "renders 404 with the model name for an unknown card" do
      get :index, params: { reader_card_number: "999999" }

      expect(response).to have_http_status(:not_found)
      expect(body["errors"].first).to eq("code" => "not_found", "message" => "Reader not found", "field" => nil)
    end
  end
end
