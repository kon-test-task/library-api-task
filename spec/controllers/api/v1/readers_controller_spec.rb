require "rails_helper"

RSpec.describe Api::V1::ReadersController, type: :controller do
  let(:first_error) { JSON.parse(response.body)["errors"].first }

  describe "GET #show" do
    it "renders the reader as JSON" do
      reader = create(:reader, card_number: "100009")

      get :show, params: { card_number: "100009" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "card_number" => reader.card_number,
        "full_name" => reader.full_name,
        "email" => reader.email
      )
    end
  end

  describe "POST #create" do
    let(:reader) { build(:reader) }

    before { allow(Reader).to receive(:new).and_return(reader) }

    { "index_readers_on_email" => "email", "index_readers_on_card_number" => "card_number" }.each do |index, field|
      it "renders a lost race on #{index} as taken on #{field}" do
        allow(reader).to receive(:save).and_raise(ActiveRecord::RecordNotUnique, "duplicate key value violates #{index}")

        post :create, params: { card_number: "100009" }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(first_error).to include("code" => "taken", "field" => field)
      end
    end
  end

  describe "PATCH #update" do
    it "reads the card number from the body, not the path" do
      reader = create(:reader, card_number: "100009")

      patch :update, params: { card_number: "100009" }, body: { card_number: "100010" }.to_json, as: :json

      expect(reader.reload.card_number).to eq("100010")
    end
  end

  describe "DELETE #destroy" do
    it "renders 409 when the model refuses, with nothing removed" do
      loan = create(:borrowing)

      expect { delete :destroy, params: { card_number: loan.reader.card_number } }.not_to change(Reader, :count)
      expect(response).to have_http_status(:conflict)
      expect(first_error).to eq("code" => "has_loans", "message" => "Reader has loans and cannot be deleted", "field" => nil)
    end

    it "renders an empty 204 on success" do
      delete :destroy, params: { card_number: create(:reader).card_number }

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end
  end
end
