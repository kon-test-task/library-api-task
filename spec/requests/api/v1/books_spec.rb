require "swagger_helper"

RSpec.describe "Books API", type: :request do
  include_context "with OpenAPI example data"

  path "/api/v1/books" do
    get "Lists books with their status and current borrower" do
      tags "Books"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false, description: "Page number, starting at 1", example: 1
      parameter name: :limit, in: :query, type: :integer, required: false, description: "Books per page, 20 by default, 100 at most", example: 20
      parameter name: :author, in: :query, type: :string, required: false, description: "Case-insensitive fragment of an author's name"

      response "200", "books listed" do
        schema type: :object,
               required: %w[books meta],
               properties: {
                 books: { type: :array, items: { "$ref" => "#/components/schemas/book" } },
                 meta: { "$ref" => "#/components/schemas/pagination" }
               }

        example_response :books, "One available book and one borrowed book", {
          books: [ OpenapiExamples::AVAILABLE_BOOK, OpenapiExamples::BORROWED_BOOK ],
          meta: { count: 2, page: 1, limit: 20, last: 1 }
        }

        before { available_book && borrowed_book }

        run_test!
      end

      response "200", "books listed" do
        schema type: :object,
               required: %w[books meta],
               properties: {
                 books: { type: :array, items: { "$ref" => "#/components/schemas/book" } },
                 meta: { "$ref" => "#/components/schemas/pagination" }
               }

        example_response :second_page, "Page 2 of 3, with previous and next", {
          books: [ OpenapiExamples::BORROWED_BOOK ],
          meta: OpenapiExamples::SECOND_PAGE_META
        }

        let(:page) { 2 }
        let(:limit) { 1 }

        before { available_book && borrowed_book && create(:book, serial_number: "000103") }

        run_test!
      end

      response "422", "invalid pagination" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_pagination, "A negative limit",
                      code: "invalid_pagination", message: "limit must be at least 1", field: "limit"

        let(:limit) { -5 }

        run_test!
      end

      bad_request_response { let(:page) { "\xE0" } }

      internal_error_response { before { allow(Book).to receive(:includes).and_raise("boom") } }
    end

    post "Adds a book" do
      tags "Books"
      consumes "application/json"
      produces "application/json"
      parameter name: :book_body, in: :body, required: true, schema: {
        type: :object,
        required: %w[serial_number title],
        properties: {
          serial_number: { type: :string, pattern: OpenapiExamples::SIX_DIGITS, description: "Six digits, leading zeros included", example: OpenapiExamples::TWO_AUTHOR_REQUEST[:serial_number] },
          title: { type: :string, example: OpenapiExamples::TWO_AUTHOR_REQUEST[:title] },
          author: { type: :string, description: "One author. Send this or authors, not both", example: OpenapiExamples::ONE_AUTHOR_REQUEST[:author] },
          authors: { type: :array, items: { type: :string }, description: "Authors in display order", example: OpenapiExamples::TWO_AUTHOR_REQUEST[:authors] }
        }
      }
      request_body_example name: :two_authors, summary: "Two authors, in display order", value: OpenapiExamples::TWO_AUTHOR_REQUEST
      request_body_example name: :one_author, summary: "One author", value: OpenapiExamples::ONE_AUTHOR_REQUEST

      response "201", "book created" do
        schema "$ref" => "#/components/schemas/book"

        example_response :created, "The new book, available", OpenapiExamples::TWO_AUTHOR_REQUEST.merge(
          status: "available",
          author: "Andrew Hunt, David Thomas",
          borrowed: false,
          current_loan: nil
        )

        let(:book_body) { OpenapiExamples::TWO_AUTHOR_REQUEST }

        run_test!
      end

      response "201", "book created" do
        schema "$ref" => "#/components/schemas/book"

        example_response :created_one_author, "A new book with one author", OpenapiExamples::ONE_AUTHOR_REQUEST.merge(
          status: "available",
          authors: [ OpenapiExamples::ONE_AUTHOR_REQUEST[:author] ],
          borrowed: false,
          current_loan: nil
        )

        let(:book_body) { OpenapiExamples::ONE_AUTHOR_REQUEST }

        run_test!
      end

      response "400", "the request could not be read" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_json, "A body that does not parse",
                      code: "invalid_json", message: "Request body is not valid JSON"

        let(:book_body) { double(to_json: '{"title":') }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_response :invalid_fields, "Bad serial number and blank title", {
          errors: [
            { code: "invalid", message: "Serial number must be a 6-digit number", field: "serial_number" },
            { code: "blank", message: "Title can't be blank", field: "title" }
          ]
        }

        let(:book_body) { { serial_number: "12a456", title: "", author: "Sandi Metz" } }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :taken, "A serial number another book uses",
                      code: "taken", message: "Serial number has already been taken", field: "serial_number"

        let(:book_body) { { serial_number: available_book.serial_number, title: "Another Book", author: "Sandi Metz" } }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :ambiguous_authors, "Both author and authors in one request",
                      code: "ambiguous_authors", message: "Send either author or authors, not both", field: "authors"

        let(:book_body) { { serial_number: "004219", title: "Title", author: "Sandi Metz", authors: [ "Sandi Metz" ] } }

        run_test!
      end

      bad_request_response { let(:book_body) { double(to_json: %({"title":"\xE0"})) } }

      internal_error_response do
        let(:book_body) { OpenapiExamples::TWO_AUTHOR_REQUEST }

        before { allow(Book).to receive(:new).and_raise("boom") }
      end
    end
  end

  path "/api/v1/books/{serial_number}" do
    get "Shows a book with its full borrowing history" do
      tags "Books"
      produces "application/json"
      parameter name: :serial_number, in: :path, type: :string, description: "Six-digit serial number", example: "000101"

      response "200", "book found" do
        schema "$ref" => "#/components/schemas/book_with_history"

        example_response :book, "A book with one returned loan", OpenapiExamples::AVAILABLE_BOOK.merge(loans: [ OpenapiExamples::RETURNED_LOAN ])

        let(:serial_number) { available_book.serial_number }

        run_test!
      end

      response "404", "no book with that serial number" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :not_found, "An unknown serial number", code: "not_found", message: "Book not found"

        let(:serial_number) { "999999" }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_characters, "A null byte in the serial number",
                      code: "invalid_characters", message: "Parameters must not contain null bytes"

        let(:serial_number) { "a%00b" }

        run_test!
      end

      bad_request_response { let(:serial_number) { "000101?page=%E0" } }

      internal_error_response do
        let(:serial_number) { "000101" }

        before { allow(Book).to receive(:with_history).and_raise("boom") }
      end
    end

    delete "Deletes a book and its returned loans" do
      tags "Books"
      produces "application/json"
      parameter name: :serial_number, in: :path, type: :string, description: "Six-digit serial number", example: "000103"

      response "204", "book deleted" do
        let(:serial_number) { create(:book, serial_number: "000103").serial_number }

        run_test! do
          expect(Book.exists?(serial_number: "000103")).to be(false)
        end
      end

      response "404", "no book with that serial number" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :not_found, "An unknown serial number", code: "not_found", message: "Book not found"

        let(:serial_number) { "999999" }

        run_test!
      end

      response "409", "book is currently borrowed" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :already_borrowed, "Serial number 000102 is on loan",
                      code: "already_borrowed", message: "Book is already borrowed"

        let(:serial_number) { borrowed_book.serial_number }

        run_test! do
          expect(Book.exists?(serial_number: "000102")).to be(true)
        end
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_characters, "A null byte in the serial number",
                      code: "invalid_characters", message: "Parameters must not contain null bytes"

        let(:serial_number) { "a%00b" }

        run_test!
      end

      bad_request_response { let(:serial_number) { "000103?page=%E0" } }

      internal_error_response do
        let(:serial_number) { "000103" }

        before { allow(Book).to receive(:find_by!).and_raise("boom") }
      end
    end
  end
end
