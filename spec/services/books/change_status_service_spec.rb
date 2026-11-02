require "rails_helper"

RSpec.describe Books::ChangeStatusService, type: :model do
  let(:book) { create(:book) }
  let!(:reader) { create(:reader, card_number: "100001") }

  def borrow(card_number: "100001")
    described_class.new(book: book, status: "borrowed", card_number: card_number).call
  end

  def give_back
    described_class.new(book: book, status: "available").call
  end

  describe "status borrowed" do
    it "lends the book to the reader with that card number" do
      borrow

      expect(book.reload).to be_borrowed
      expect(book.current_reader).to eq(reader)
    end

    it "accepts a card number with surrounding spaces" do
      borrow(card_number: " 100001 ")

      expect(book.reload.current_reader).to eq(reader)
    end

    [ nil, "", "  " ].each do |card_number|
      it "refuses a missing reader identifier: #{card_number.inspect}" do
        expect { borrow(card_number: card_number) }.to raise_error(Books::MissingCardNumber) do |error|
          expect(error).to have_attributes(code: "missing_card_number", field: :card_number)
        end
        expect(book.reload).to be_available
      end
    end

    it "refuses an unknown reader and leaves the book alone" do
      expect { borrow(card_number: "999999") }.to raise_error(Books::UnknownReader) do |error|
        expect(error).to have_attributes(code: "unknown_reader", field: :card_number)
      end
      expect(book.reload).to be_available
      expect(Borrowing.count).to eq(0)
    end

    it "does not touch the book when the reader cannot be found" do
      expect(book).not_to receive(:borrow!)

      expect { borrow(card_number: "999999") }.to raise_error(Books::UnknownReader)
    end

    it "reports invalid input ahead of a conflict" do
      borrow

      expect { borrow(card_number: "999999") }.to raise_error(Books::UnknownReader)
    end

    it "lets a refusal from the book through" do
      borrow

      expect { borrow }.to raise_error(Books::AlreadyBorrowed)
    end
  end

  describe "status available" do
    it "returns the book" do
      borrow

      give_back

      expect(book.reload).to be_available
    end

    it "ignores a card number" do
      borrow

      described_class.new(book: book, status: "available", card_number: "999999").call

      expect(book.reload).to be_available
    end

    it "lets a refusal from the book through" do
      expect { give_back }.to raise_error(Books::AlreadyAvailable)
    end
  end

  describe "other status values" do
    [ "lost", "BORROWED", "1", "", nil ].each do |status|
      it "refuses #{status.inspect}" do
        expect { described_class.new(book: book, status: status).call }.to raise_error(Books::InvalidStatus) do |error|
          expect(error).to have_attributes(code: "invalid_status", field: :status)
        end
      end
    end
  end
end
