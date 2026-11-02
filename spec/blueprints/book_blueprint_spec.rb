require "rails_helper"

RSpec.describe BookBlueprint, type: :model do
  before { freeze_time }

  let(:book) { create(:book, author_names: [ "Andrew Hunt", "David Thomas" ]) }

  describe "default serialization" do
    subject(:serialized_book) { described_class.render_as_hash(book) }

    it "includes only the book fields" do
      expect(serialized_book).to eq(
        serial_number: book.serial_number,
        title: book.title,
        status: "available",
        author: "Andrew Hunt, David Thomas",
        authors: [ "Andrew Hunt", "David Thomas" ],
        borrowed: false
      )
    end

    context "when the book has one author with a comma in the name" do
      let(:book) { create(:book, author_names: "Tolkien, J.R.R.") }

      it "keeps the name whole in both author fields" do
        expect(serialized_book).to include(author: "Tolkien, J.R.R.", authors: [ "Tolkien, J.R.R." ])
      end
    end

    context "when testing all statuses" do
      { "available" => false, "borrowed" => true }.each do |status, borrowed|
        context "when status is #{status}" do
          let(:book) { create(:book, status: status) }

          it "returns the matching status and borrowed flag" do
            expect(serialized_book).to include(status: status, borrowed: borrowed)
          end
        end
      end
    end
  end

  describe "list view" do
    subject(:serialized_book) { described_class.render_as_hash(book, view: :list) }

    context "when the book has no loans" do
      it "returns nil for the current loan" do
        expect(serialized_book[:current_loan]).to be_nil
      end

      it "leaves out the history" do
        expect(serialized_book).not_to have_key(:loans)
      end
    end

    context "when the book has an open loan" do
      let!(:loan) { create(:borrowing, book: book) }

      it "serializes the open loan" do
        expect(serialized_book[:current_loan]).to eq(BorrowingBlueprint.render_as_hash(loan))
      end
    end

    context "when the book only has returned loans" do
      let!(:loan) { create(:borrowing, :returned, book: book) }

      it "returns nil for the current loan" do
        expect(serialized_book[:current_loan]).to be_nil
      end
    end
  end

  describe "history view" do
    subject(:serialized_book) { described_class.render_as_hash(book.reload, view: :history) }

    context "when the book has no loans" do
      it "returns an empty history" do
        expect(serialized_book[:loans]).to eq([])
      end
    end

    context "when the book has returned loans and an open loan" do
      let!(:older) { create(:borrowing, :returned, book: book, borrowed_at: 40.days.ago, returned_at: 35.days.ago) }
      let!(:newer) { create(:borrowing, :returned, book: book, borrowed_at: 20.days.ago, returned_at: 15.days.ago) }
      let!(:open_loan) { create(:borrowing, book: book) }

      it "serializes every loan, newest first" do
        expect(serialized_book[:loans]).to eq(BorrowingBlueprint.render_as_hash([ open_loan, newer, older ]))
      end

      it "also serializes the open loan as the current loan" do
        expect(serialized_book[:current_loan]).to eq(BorrowingBlueprint.render_as_hash(open_loan))
      end
    end
  end
end
