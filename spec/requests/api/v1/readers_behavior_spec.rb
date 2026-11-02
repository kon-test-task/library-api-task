require "rails_helper"

# Cases beyond the rswag specs, kept out of the OpenAPI file.
RSpec.describe "Readers API behavior", type: :request do
  let(:body) { response.parsed_body }
  let(:first_error) { body["errors"].first }
  let(:valid) { { card_number: "004219", full_name: "Ada Lovelace", email: "ada@example.com" } }

  describe "GET /api/v1/readers/:card_number" do
    let!(:reader) { create(:reader, card_number: "100009", full_name: "Ada Lovelace", email: "ada@example.com") }

    it "shows the reader" do
      get "/api/v1/readers/100009"

      expect(response).to have_http_status(:ok)
      expect(body).to eq("card_number" => "100009", "full_name" => "Ada Lovelace", "email" => "ada@example.com")
    end

    it "returns 404 for an unknown reader" do
      get "/api/v1/readers/999999"

      expect(response).to have_http_status(:not_found)
      expect(first_error).to include("code" => "not_found", "message" => "Reader not found")
    end

    it "refuses a null byte in the card number" do
      get "/api/v1/readers/a%00b"

      expect(response).to have_http_status(:unprocessable_content)
      expect(first_error["code"]).to eq("invalid_characters")
    end
  end

  describe "POST /api/v1/readers" do
    it "keeps leading zeros and normalizes the name and email" do
      post "/api/v1/readers", params: valid.merge(full_name: "  Ada   Lovelace ", email: " ADA@Example.com "), as: :json

      expect(body).to eq("card_number" => "004219", "full_name" => "Ada Lovelace", "email" => "ada@example.com")
    end

    it "refuses a card number another reader has" do
      create(:reader, card_number: "004219")

      post "/api/v1/readers", params: valid, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(first_error).to include("code" => "taken", "field" => "card_number")
    end

    it "treats an email in another case as taken" do
      create(:reader, email: "ada@example.com")

      post "/api/v1/readers", params: valid.merge(email: "ADA@EXAMPLE.COM"), as: :json

      expect(first_error).to include("code" => "taken", "field" => "email")
    end

    it "reports every missing field for an empty body" do
      post "/api/v1/readers", params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["errors"].pluck("field")).to contain_exactly("card_number", "full_name", "email")
    end

    it "ignores fields a client may not set" do
      post "/api/v1/readers", params: valid.merge(id: 987_654), as: :json

      expect(response).to have_http_status(:created)
      expect(Reader.find_by!(card_number: "004219").id).not_to eq(987_654)
    end

    it "refuses a null byte in the body" do
      post "/api/v1/readers", params: valid.merge(full_name: "a\u0000b"), as: :json

      expect(first_error["code"]).to eq("invalid_characters")
    end
  end

  describe "PATCH /api/v1/readers/:card_number" do
    let!(:reader) { create(:reader, card_number: "100009", full_name: "Old Name", email: "old@example.com") }

    it "changes only the fields it receives" do
      patch "/api/v1/readers/100009", params: { full_name: "New Name" }, as: :json

      expect(body).to eq("card_number" => "100009", "full_name" => "New Name", "email" => "old@example.com")
    end

    it "changes the card number, and the old number then returns 404" do
      patch "/api/v1/readers/100009", params: { card_number: "100010" }, as: :json

      expect(body["card_number"]).to eq("100010")

      get "/api/v1/readers/100009/books"

      expect(response).to have_http_status(:not_found)
    end

    it "keeps the reader's loans under the new card number" do
      loan = create(:borrowing, reader: reader)

      patch "/api/v1/readers/100009", params: { card_number: "100010" }, as: :json

      expect(loan.reload.reader.card_number).to eq("100010")
    end

    it "refuses a bad new card number and changes nothing" do
      patch "/api/v1/readers/100009", params: { card_number: "12a456" }, as: :json

      expect(first_error).to include("code" => "invalid", "field" => "card_number")
      expect(reader.reload.card_number).to eq("100009")
    end

    it "refuses a null byte in a new card number" do
      patch "/api/v1/readers/100009", params: { card_number: "1\u000000010" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(first_error["code"]).to eq("invalid_characters")
    end

    it "leaves the reader alone for an empty body" do
      patch "/api/v1/readers/100009", params: {}, as: :json

      expect(response).to have_http_status(:ok)
      expect(body["full_name"]).to eq("Old Name")
    end
  end

  describe "DELETE /api/v1/readers/:card_number" do
    let(:reader) { create(:reader) }

    it "deletes a reader with no loans" do
      delete "/api/v1/readers/#{reader.card_number}"

      expect(response).to have_http_status(:no_content)
      expect(Reader.exists?(reader.id)).to be(false)
    end

    it "refuses a reader with an open loan" do
      create(:borrowing, reader: reader)

      delete "/api/v1/readers/#{reader.card_number}"

      expect(response).to have_http_status(:conflict)
      expect(first_error["code"]).to eq("has_loans")
    end

    it "refuses a reader with only returned loans and keeps the history" do
      loan = create(:borrowing, :returned, reader: reader)

      delete "/api/v1/readers/#{reader.card_number}"

      expect(response).to have_http_status(:conflict)
      expect(Borrowing.exists?(loan.id)).to be(true)
    end
  end
end
