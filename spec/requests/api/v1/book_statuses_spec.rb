require "swagger_helper"

RSpec.describe "Book status API", type: :request do
  include_context "with OpenAPI example data"

  path "/api/v1/books/{serial_number}/status" do
    patch "Lends a book to a reader or marks it returned" do
      tags "Books"
      consumes "application/json"
      produces "application/json"
      parameter name: :serial_number, in: :path, type: :string, description: "Six-digit serial number", example: "000101"
      parameter name: :status_body, in: :body, required: true, schema: {
        type: :object,
        required: %w[status],
        properties: {
          status: { type: :string, enum: %w[borrowed available], example: OpenapiExamples::LEND_REQUEST[:status] },
          card_number: { type: :string, pattern: OpenapiExamples::SIX_DIGITS, description: "Six digits. Required when status is borrowed", example: OpenapiExamples::LEND_REQUEST[:card_number] }
        }
      }
      request_body_example name: :lend, summary: "Lend the book to a reader", value: OpenapiExamples::LEND_REQUEST
      request_body_example name: :return, summary: "Mark the book returned", value: { status: "available" }

      let(:serial_number) { available_book.serial_number }

      response "200", "status changed" do
        schema "$ref" => "#/components/schemas/book_with_history"

        new_loan = { borrowed_at: "2026-11-02T09:00:00.000+01:00", due_date: "2026-12-02", returned_at: nil, reader: OpenapiExamples::JAN }

        example_response :lent, "Lent to card 100001, due in 30 days", OpenapiExamples::AVAILABLE_BOOK.merge(
          status: "borrowed",
          borrowed: true,
          current_loan: new_loan,
          loans: [ new_loan, OpenapiExamples::RETURNED_LOAN ]
        )

        let(:status_body) { OpenapiExamples::LEND_REQUEST }

        before { jan }

        run_test!
      end

      response "200", "status changed" do
        schema "$ref" => "#/components/schemas/book_with_history"

        example_response :returned, "Returned, with returned_at set", OpenapiExamples::BORROWED_BOOK.merge(
          status: "available",
          borrowed: false,
          current_loan: nil,
          loans: [ OpenapiExamples::OPEN_LOAN.merge(returned_at: "2026-11-02T09:00:00.000+01:00") ]
        )

        let(:serial_number) { borrowed_book.serial_number }
        let(:status_body) { { status: "available" } }

        run_test!
      end

      response "400", "the request could not be read" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_json, "A body that does not parse",
                      code: "invalid_json", message: "Request body is not valid JSON"

        let(:status_body) { double(to_json: '{"status":') }

        run_test!
      end

      response "404", "no book with that serial number" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :not_found, "An unknown serial number", code: "not_found", message: "Book not found"

        let(:serial_number) { "999999" }
        let(:status_body) { { status: "available" } }

        run_test!
      end

      response "409", "the book's state refuses the change" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :already_borrowed, "Lending a book that is on loan",
                      code: "already_borrowed", message: "Book is already borrowed"

        let(:serial_number) { borrowed_book.serial_number }
        let(:status_body) { { status: "borrowed", card_number: anna.card_number } }

        run_test!
      end

      response "409", "the book's state refuses the change" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :already_available, "Returning a book that is not on loan",
                      code: "already_available", message: "Book is already available"

        let(:status_body) { { status: "available" } }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :unknown_reader, "A card number no reader has", **OpenapiExamples::UNKNOWN_READER_ERROR

        let(:status_body) { { status: "borrowed", card_number: "999999" } }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :missing_card_number, "Lending without a card number",
                      code: "missing_card_number", message: "card_number is required to borrow a book", field: "card_number"

        let(:status_body) { { status: "borrowed" } }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_status, "A status other than borrowed or available",
                      code: "invalid_status", message: "Status must be borrowed or available", field: "status"

        let(:status_body) { { status: "lost" } }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :parameter_missing, "No status in the body",
                      code: "parameter_missing", message: "status is required", field: "status"

        let(:status_body) { { card_number: "100001" } }

        run_test!
      end

      bad_request_response do
        # The template adds /status after this value, which lands in the unused x parameter.
        let(:serial_number) { "000101/status?page=%E0&x=" }
        let(:status_body) { { status: "available" } }
      end

      internal_error_response do
        let(:serial_number) { "000101" }
        let(:status_body) { { status: "available" } }

        before { allow(Book).to receive(:find_by!).and_raise("boom") }
      end
    end
  end
end
