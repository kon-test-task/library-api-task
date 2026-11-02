require "rails_helper"

RSpec.describe Api::V1::BookStatusesController, type: :controller do
  let(:book) { create(:book) }
  let(:service) { instance_double(Books::ChangeStatusService, call: nil) }
  let(:first_error) { JSON.parse(response.body)["errors"].first }

  before { allow(Books::ChangeStatusService).to receive(:new).and_return(service) }

  describe "PATCH #update" do
    it "passes the book, status and card number to the service" do
      patch :update, params: { serial_number: book.serial_number, status: "borrowed", card_number: "100001" }

      expect(Books::ChangeStatusService).to have_received(:new).with(book: book, status: "borrowed", card_number: "100001")
      expect(service).to have_received(:call)
    end

    it "does not build the service for an unknown book" do
      patch :update, params: { serial_number: "999999", status: "available" }

      expect(response).to have_http_status(:not_found)
      expect(Books::ChangeStatusService).not_to have_received(:new)
    end

    it "does not build the service without a status" do
      patch :update, params: { serial_number: book.serial_number }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Books::ChangeStatusService).not_to have_received(:new)
    end

    it "renders a refusal from the book as 409" do
      allow(service).to receive(:call).and_raise(Books::AlreadyBorrowed)

      patch :update, params: { serial_number: book.serial_number, status: "borrowed" }

      expect(response).to have_http_status(:conflict)
      expect(first_error).to eq("code" => "already_borrowed", "message" => "Book is already borrowed", "field" => nil)
    end

    it "renders invalid input from the service as 422" do
      allow(service).to receive(:call).and_raise(Books::UnknownReader)

      patch :update, params: { serial_number: book.serial_number, status: "borrowed" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(first_error).to eq("code" => "unknown_reader", "message" => "No reader has that card number", "field" => "card_number")
    end
  end
end
