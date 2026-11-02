require "swagger_helper"

RSpec.describe "Reader books API", type: :request do
  include_context "with OpenAPI example data"

  path "/api/v1/readers/{card_number}/books" do
    get "Lists the books a reader has on loan" do
      tags "Readers"
      produces "application/json"
      parameter name: :card_number, in: :path, type: :string, description: "Six-digit library card number", example: "100001"
      parameter name: :page, in: :query, type: :integer, required: false, description: "Page number, starting at 1", example: 1
      parameter name: :limit, in: :query, type: :integer, required: false, description: "Loans per page, 20 by default, 100 at most", example: 20
      parameter name: :include_returned, in: :query, type: :boolean, required: false, description: "Send true to add returned loans, for the reader's full history"

      response "200", "loans listed" do
        schema "$ref" => "#/components/schemas/reader_loans"

        example_response :on_loan, "The books on loan to card 100001", {
          reader: OpenapiExamples::JAN,
          loans: [ OpenapiExamples::OPEN_LOAN.except(:reader).merge(book: OpenapiExamples::BORROWED_BOOK.slice(:serial_number, :title, :author)) ],
          meta: { count: 1, page: 1, limit: 20, last: 1 }
        }

        let(:card_number) { jan.card_number }

        before { available_book && borrowed_book }

        run_test!
      end

      response "200", "loans listed" do
        schema "$ref" => "#/components/schemas/reader_loans"

        example_response :with_returned, "The full history of card 100002, with include_returned=true", {
          reader: OpenapiExamples::ANNA,
          loans: [ OpenapiExamples::RETURNED_LOAN.except(:reader).merge(book: OpenapiExamples::AVAILABLE_BOOK.slice(:serial_number, :title, :author)) ],
          meta: { count: 1, page: 1, limit: 20, last: 1 }
        }

        let(:card_number) { anna.card_number }
        let(:include_returned) { true }

        before { available_book }

        run_test!
      end

      response "404", "no reader with that card number" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :not_found, "An unknown card number", code: "not_found", message: "Reader not found"

        let(:card_number) { "999999" }

        run_test!
      end

      response "422", "invalid pagination" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_pagination, "A negative limit",
                      code: "invalid_pagination", message: "limit must be at least 1", field: "limit"

        let(:card_number) { jan.card_number }
        let(:limit) { -5 }

        run_test!
      end

      # The template adds /books after this value, which lands in the unused x parameter.
      bad_request_response { let(:card_number) { "100001/books?page=%E0&x=" } }

      internal_error_response do
        let(:card_number) { "100001" }

        before { allow(Reader).to receive(:find_by!).and_raise("boom") }
      end
    end
  end
end
