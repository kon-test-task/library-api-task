require "rails_helper"

# Cases beyond the one-example-per-code rswag specs, kept out of the OpenAPI file.
RSpec.describe "Books API behavior", type: :request do
  let(:body) { JSON.parse(response.body) }

  def serials
    body["books"].map { |book| book["serial_number"] }
  end

  describe "GET /api/v1/books" do
    it "stays free of N+1 queries with several borrowed books" do
      3.times { create(:borrowing, book: create(:book, author_names: [ "Andrew Hunt", "David Thomas" ])) }

      get "/api/v1/books"

      expect(response).to have_http_status(:ok)
      expect(body["books"].size).to eq(3)
    end

    describe "author search" do
      before do
        create(:book, serial_number: "000001", author_names: [ "J.R.R. Tolkien" ])
        create(:book, serial_number: "000002", author_names: [ "Andrew Hunt", "David Thomas" ])
        create(:book, serial_number: "000003", author_names: [ "100% Real Author" ])
      end

      it "finds a surname fragment in any case" do
        get "/api/v1/books", params: { author: "tOLk" }

        expect(serials).to eq([ "000001" ])
      end

      it "returns both authors of a two-author book and counts it once" do
        get "/api/v1/books", params: { author: "h" }

        book = body["books"].find { |found| found["serial_number"] == "000002" }

        expect(book["authors"]).to eq([ "Andrew Hunt", "David Thomas" ])
        expect(body["meta"]["count"]).to eq(serials.size)
        expect(serials.count("000002")).to eq(1)
      end

      it "matches a literal percent sign only" do
        get "/api/v1/books", params: { author: "%" }

        expect(serials).to eq([ "000003" ])
      end

      it "returns an empty list when nothing matches" do
        get "/api/v1/books", params: { author: "nobody" }

        expect(serials).to be_empty
        expect(body["meta"]["count"]).to eq(0)
      end

      it "ignores a blank search" do
        get "/api/v1/books", params: { author: "" }

        expect(serials.size).to eq(3)
      end

      it "does not fail on a nested param" do
        get "/api/v1/books", params: { author: { a: "b" } }

        expect(response).to have_http_status(:ok)
      end
    end

    describe "pagination" do
      before { 3.times { create(:book) } }

      it "pages through results" do
        get "/api/v1/books", params: { page: 2, limit: 2 }

        expect(body["books"].size).to eq(1)
        expect(body["meta"]).to include("count" => 3, "page" => 2, "limit" => 2, "last" => 2, "previous" => 1)
      end

      it "caps the limit at 100" do
        get "/api/v1/books", params: { limit: 1000 }

        expect(body["meta"]["limit"]).to eq(100)
      end

      it "returns an empty page past the end" do
        get "/api/v1/books", params: { page: 50 }

        expect(response).to have_http_status(:ok)
        expect(body["books"]).to be_empty
      end

      [ "abc", "0" ].each do |value|
        it "falls back to the defaults for page and limit #{value}" do
          get "/api/v1/books", params: { page: value, limit: value }

          expect(response).to have_http_status(:ok)
          expect(body["meta"]).to include("page" => 1, "limit" => 20)
        end
      end

      it "treats a negative page as page 1" do
        get "/api/v1/books", params: { page: -3 }

        expect(body["meta"]["page"]).to eq(1)
      end

      it "returns the error format for a negative limit" do
        get "/api/v1/books", params: { limit: -5 }

        expect(response).to have_http_status(:unprocessable_content)
        expect(body["errors"].first).to include("code" => "invalid_pagination", "field" => "limit")
      end
    end
  end

  describe "GET /api/v1/books/:serial_number" do
    it "finds a serial with leading zeros, not the book whose id matches its digits" do
      other = create(:book, serial_number: "555555")
      create(:book, serial_number: format("%06d", other.id), title: "Right book")

      get "/api/v1/books/#{format("%06d", other.id)}"

      expect(body["title"]).to eq("Right book")
    end

    it "returns 404 for a database id" do
      book = create(:book, serial_number: "555555")

      get "/api/v1/books/#{book.id}"

      expect(response).to have_http_status(:not_found)
    end

    it "includes the open loan in both the current loan and the history" do
      loan = create(:borrowing)

      get "/api/v1/books/#{loan.book.serial_number}"

      expect(body["current_loan"]["returned_at"]).to be_nil
      expect(body["loans"].size).to eq(1)
    end
  end

  describe "POST /api/v1/books" do
    let(:valid) { { serial_number: "004219", title: "Practical Object-Oriented Design" } }

    it "accepts a single author and does not split on commas" do
      post "/api/v1/books", params: valid.merge(author: "Tolkien, J.R.R."), as: :json

      expect(response).to have_http_status(:created)
      expect(body["authors"]).to eq([ "Tolkien, J.R.R." ])
      expect(body["author"]).to eq("Tolkien, J.R.R.")
    end

    it "refuses both author and authors" do
      post "/api/v1/books", params: valid.merge(author: "Sandi Metz", authors: [ "Sandi Metz" ]), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["errors"].first).to include("code" => "ambiguous_authors", "field" => "authors")
      expect(Book.count).to eq(0)
    end

    it "requires an author" do
      post "/api/v1/books", params: valid, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["errors"].first).to include("code" => "blank", "field" => "authors")
    end

    it "treats a string in authors as no author, not as a list" do
      post "/api/v1/books", params: valid.merge(authors: "Sandi Metz"), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "reports a duplicate serial number" do
      create(:book, serial_number: "004219")

      post "/api/v1/books", params: valid.merge(author: "Sandi Metz"), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["errors"].first).to include("code" => "taken", "field" => "serial_number")
    end

    it "reports a duplicate serial number when a race reaches the unique index" do
      create(:book, serial_number: "004219")
      allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each)

      post "/api/v1/books", params: valid.merge(author: "Sandi Metz"), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["errors"].first).to include("code" => "taken", "field" => "serial_number")
    end

    it "returns the error format for malformed JSON" do
      post "/api/v1/books", params: "{not json", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(body["errors"].first).to include("code" => "invalid_json", "field" => nil)
    end
  end

  describe "null bytes" do
    def expect_invalid_characters
      expect(response).to have_http_status(:unprocessable_content)
      expect(body["errors"].first).to include("code" => "invalid_characters", "field" => nil)
    end

    it "refuses one in a JSON field" do
      post "/api/v1/books", params: { serial_number: "004219", title: "a\u0000b", author: "Sandi Metz" }, as: :json

      expect_invalid_characters
    end

    it "refuses one in an author list" do
      post "/api/v1/books", params: { serial_number: "004219", title: "Title", authors: [ "a\u0000b" ] }, as: :json

      expect_invalid_characters
    end

    it "refuses one in the search text" do
      get "/api/v1/books", params: { author: "a\u0000b" }

      expect_invalid_characters
    end

    it "refuses one in the URL" do
      get "/api/v1/books/a%00b"

      expect_invalid_characters
    end

    it "still searches for the literal text %00" do
      get "/api/v1/books", params: { author: "%00" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /api/v1/books/:serial_number" do
    it "deletes an available book's returned loans too" do
      loan = create(:borrowing, :returned)

      expect { delete "/api/v1/books/#{loan.book.serial_number}" }.to change(Borrowing, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
