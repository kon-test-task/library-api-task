require "rails_helper"

RSpec.describe Api::V1::BooksController, type: :controller do
  let(:body) { JSON.parse(response.body) }

  describe "GET #index" do
    it "orders books by serial number" do
      create(:book, serial_number: "000002")
      create(:book, serial_number: "000001")

      get :index

      expect(body["books"].map { |book| book["serial_number"] }).to eq(%w[000001 000002])
    end

    it "filters by title and by author together" do
      create(:book, serial_number: "000001", title: "The Hobbit", author_names: [ "J.R.R. Tolkien" ])
      create(:book, serial_number: "000002", title: "The Hobbit Companion", author_names: [ "Someone Else" ])
      create(:book, serial_number: "000003", title: "The Silmarillion", author_names: [ "J.R.R. Tolkien" ])

      get :index, params: { title: "hobbit", author: "tolkien" }

      expect(body["books"].map { |book| book["serial_number"] }).to eq(%w[000001])
    end

    it "renders the shared pagination metadata" do
      create(:book)

      get :index, params: { limit: 1 }
      expect(body["meta"]).to eq("count" => 1, "page" => 1, "limit" => 1, "last" => 1)
    end

    it "renders a negative limit as 422" do
      get :index, params: { limit: -5 }

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["errors"].first["code"]).to eq("invalid_pagination")
    end
  end

  describe "POST #create" do
    let(:valid) { { serial_number: "004219", title: "Title", author: "Sandi Metz" } }

    it "ignores fields a client may not set" do
      post :create, params: valid.merge(status: "borrowed", id: 987_654), as: :json

      expect(response).to have_http_status(:created)

      book = Book.find_by!(serial_number: "004219")
      expect(book).to be_available
      expect(book.id).not_to eq(987_654)
    end

    it "never builds a book when both author fields arrive" do
      expect(Book).not_to receive(:new)

      post :create, params: valid.merge(authors: [ "Sandi Metz" ]), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "reports no author when authors holds a string, not a list" do
      post :create, params: valid.except(:author).merge(authors: "Sandi Metz"), as: :json

      expect(body["errors"].first).to include("field" => "authors")
    end
  end

  describe "DELETE #destroy" do
    it "renders 409 when the guard refuses, with nothing removed" do
      loan = create(:borrowing)

      expect { delete :destroy, params: { serial_number: loan.book.serial_number } }.not_to change(Book, :count)
      expect(response).to have_http_status(:conflict)
    end

    it "renders an empty 204 on success" do
      book = create(:book)

      delete :destroy, params: { serial_number: book.serial_number }

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end
  end
end
