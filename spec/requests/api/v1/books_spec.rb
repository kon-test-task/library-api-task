require "swagger_helper"

RSpec.describe "Books API", type: :request do
  path "/api/v1/books" do
    get "Lists books with their status and current borrower" do
      tags "Books"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false, description: "Page number, starting at 1"
      parameter name: :limit, in: :query, type: :integer, required: false, description: "Books per page, 20 by default, 100 at most"
      parameter name: :author, in: :query, type: :string, required: false, description: "Case-insensitive fragment of an author's name"

      response "200", "books listed" do
        schema type: :object,
               required: %w[books meta],
               properties: {
                 books: { type: :array, items: { "$ref" => "#/components/schemas/book" } },
                 meta: { "$ref" => "#/components/schemas/pagination" }
               }

        before do
          create(:book, serial_number: "000101", title: "On the shelf")
          borrowed = create(:book, serial_number: "000102", title: "Out on loan", status: :borrowed)
          create(:borrowing, book: borrowed, reader: create(:reader, card_number: "100001", full_name: "Ada Lovelace"))
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          available, borrowed = body["books"]

          expect(body["meta"]).to include("count" => 2, "page" => 1, "limit" => 20, "last" => 1)
          expect(available).to include("serial_number" => "000101", "status" => "available", "borrowed" => false, "current_loan" => nil)
          expect(borrowed).to include("serial_number" => "000102", "status" => "borrowed", "borrowed" => true)
          expect(borrowed.dig("current_loan", "reader")).to include("card_number" => "100001", "full_name" => "Ada Lovelace")
        end
      end
    end

    post "Adds a book" do
      tags "Books"
      consumes "application/json"
      produces "application/json"
      parameter name: :book_body, in: :body, schema: {
        type: :object,
        required: %w[serial_number title],
        properties: {
          serial_number: { type: :string, description: "Six digits" },
          title: { type: :string },
          author: { type: :string, description: "One author. Send this or authors, not both" },
          authors: { type: :array, items: { type: :string }, description: "Authors in display order" }
        }
      }

      response "201", "book created" do
        schema "$ref" => "#/components/schemas/book"

        let(:book_body) { { serial_number: "004219", title: "The Pragmatic Programmer", authors: [ "Andrew Hunt", "David Thomas" ] } }

        run_test! do |response|
          expect(JSON.parse(response.body)).to include(
            "serial_number" => "004219",
            "status" => "available",
            "author" => "Andrew Hunt, David Thomas",
            "authors" => [ "Andrew Hunt", "David Thomas" ]
          )
        end
      end

      response "422", "invalid fields" do
        schema "$ref" => "#/components/schemas/errors"

        let(:book_body) { { serial_number: "12a456", title: "", author: "Sandi Metz" } }

        run_test! do |response|
          errors = JSON.parse(response.body)["errors"]

          expect(errors).to include(
            { "code" => "invalid", "message" => "Serial number must be a 6-digit number", "field" => "serial_number" },
            { "code" => "blank", "message" => "Title can't be blank", "field" => "title" }
          )
        end
      end
    end
  end

  path "/api/v1/books/{serial_number}" do
    parameter name: :serial_number, in: :path, type: :string, description: "Six-digit serial number"

    get "Shows a book with its full borrowing history" do
      tags "Books"
      produces "application/json"

      response "200", "book found" do
        schema "$ref" => "#/components/schemas/book_with_history"

        let(:book) { create(:book, serial_number: "000101") }
        let(:serial_number) { book.serial_number }
        let!(:older) { create(:borrowing, :returned, book: book, borrowed_at: 40.days.ago, returned_at: 35.days.ago) }
        let!(:newer) { create(:borrowing, :returned, book: book, borrowed_at: 20.days.ago, returned_at: 15.days.ago) }

        run_test! do |response|
          loans = JSON.parse(response.body)["loans"]

          expect(loans.map { |loan| loan.dig("reader", "card_number") })
            .to eq([ newer.reader.card_number, older.reader.card_number ])
          expect(loans.first["returned_at"]).to be_present
        end
      end

      response "404", "no book with that serial number" do
        schema "$ref" => "#/components/schemas/errors"

        let(:serial_number) { "999999" }

        run_test! do |response|
          expect(JSON.parse(response.body)["errors"].first).to eq(
            "code" => "not_found", "message" => "Book not found", "field" => nil
          )
        end
      end
    end

    delete "Deletes a book and its returned loans" do
      tags "Books"
      produces "application/json"

      response "204", "book deleted" do
        let(:serial_number) { create(:book).serial_number }

        run_test! do
          expect(Book.exists?(serial_number: serial_number)).to be(false)
        end
      end

      response "404", "no book with that serial number" do
        schema "$ref" => "#/components/schemas/errors"

        let(:serial_number) { "999999" }

        run_test!
      end

      response "409", "book is currently borrowed" do
        schema "$ref" => "#/components/schemas/errors"

        let(:serial_number) { create(:borrowing).book.serial_number }

        run_test! do |response|
          expect(JSON.parse(response.body)["errors"].first).to eq(
            "code" => "already_borrowed", "message" => "Book is already borrowed", "field" => nil
          )
          expect(Book.exists?(serial_number: serial_number)).to be(true)
        end
      end
    end
  end
end
