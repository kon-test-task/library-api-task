require "swagger_helper"

RSpec.describe "Book status API", type: :request do
  path "/api/v1/books/{serial_number}/status" do
    patch "Lends a book to a reader or marks it returned" do
      tags "Books"
      consumes "application/json"
      produces "application/json"
      parameter name: :serial_number, in: :path, type: :string, description: "Six-digit serial number"
      parameter name: :status_body, in: :body, schema: {
        type: :object,
        required: %w[status],
        properties: {
          status: { type: :string, enum: %w[borrowed available] },
          card_number: { type: :string, description: "Six digits. Required when status is borrowed" }
        }
      }

      let(:book) { create(:book) }
      let(:serial_number) { book.serial_number }
      let!(:reader) { create(:reader, card_number: "100001") }

      response "200", "status changed" do
        schema "$ref" => "#/components/schemas/book_with_history"

        let(:status_body) { { status: "borrowed", card_number: "100001" } }

        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body).to include("status" => "borrowed", "borrowed" => true)
          expect(body["current_loan"]).to include("due_date" => 30.days.from_now.to_date.iso8601)
          expect(body.dig("current_loan", "reader", "card_number")).to eq("100001")
        end
      end

      response "404", "no book with that serial number" do
        schema "$ref" => "#/components/schemas/errors"

        let(:serial_number) { "999999" }
        let(:status_body) { { status: "available" } }

        run_test!
      end

      response "409", "the book's state refuses the change" do
        schema "$ref" => "#/components/schemas/errors"

        let(:status_body) { { status: "borrowed", card_number: "100001" } }

        before { create(:borrowing, book: book) && book.borrowed! }

        run_test! do |response|
          expect(JSON.parse(response.body)["errors"].first).to eq(
            "code" => "already_borrowed", "message" => "Book is already borrowed", "field" => nil
          )
        end
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        let(:status_body) { { status: "borrowed", card_number: "999999" } }

        run_test! do |response|
          expect(JSON.parse(response.body)["errors"].first).to eq(
            "code" => "unknown_reader", "message" => "No reader has that card number", "field" => "card_number"
          )
        end
      end
    end
  end
end
