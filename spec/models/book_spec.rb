require "rails_helper"

RSpec.describe Book, type: :model do
  subject { build(:book) }

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_uniqueness_of(:serial_number).ignoring_case_sensitivity }

  it "starts as available" do
    expect(create(:book)).to be_available
  end

  describe "serial_number" do
    it "accepts six digits and keeps leading zeros" do
      book = create(:book, serial_number: "004219")

      expect(book.reload.serial_number).to eq("004219")
    end

    it "strips surrounding whitespace" do
      expect(build(:book, serial_number: " 004219 ").serial_number).to eq("004219")
    end

    [ "12345", "1234567", "12a456", "", nil, "123456\n789012" ].each do |value|
      it "rejects #{value.inspect}" do
        book = build(:book, serial_number: value)

        expect(book).not_to be_valid
        expect(book.errors[:serial_number]).to include("must be a 6-digit number")
      end
    end

    it "is guarded by a database CHECK constraint" do
      book = create(:book)

      expect { book.update_column(:serial_number, "12a456") }.to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "authors" do
    it "requires at least one author" do
      book = build(:book, author_names: [])

      expect(book).not_to be_valid
      expect(book.errors[:authors]).to include("must include at least one author")
    end

    it "treats blank names as no author" do
      expect(build(:book, author_names: [ " ", nil ])).not_to be_valid
    end

    it "keeps author order, which is not alphabetical" do
      book = create(:book, author_names: [ "Zadie Smith", "Andrew Hunt", "Maya Angelou" ])

      expect(book.reload.authors.map(&:name)).to eq([ "Zadie Smith", "Andrew Hunt", "Maya Angelou" ])
    end

    it "keeps author order when preloaded" do
      id = create(:book, author_names: [ "Zadie Smith", "Andrew Hunt" ]).id

      expect(Book.includes(:authors).find(id).authors.map(&:name)).to eq([ "Zadie Smith", "Andrew Hunt" ])
    end

    it "accepts a single string and never splits it on commas" do
      book = create(:book, author_names: "Tolkien, J.R.R.")

      expect(book.reload.authors.map(&:name)).to eq([ "Tolkien, J.R.R." ])
    end

    it "reuses an existing author regardless of case" do
      existing = create(:author, name: "Sandi Metz")

      book = create(:book, author_names: [ "SANDI  METZ" ])

      expect(book.reload.authors).to eq([ existing ])
      expect(existing.reload.name).to eq("Sandi Metz")
    end

    it "lists a name repeated in different case once" do
      book = create(:book, author_names: [ "Sandi Metz", "sandi metz" ])

      expect(book.reload.authors.map(&:name)).to eq([ "Sandi Metz" ])
    end

    it "replaces the authors on update" do
      book = create(:book, author_names: [ "Andrew Hunt", "David Thomas" ])

      book.update!(author_names: [ "David Thomas" ])

      expect(book.reload.authors.map(&:name)).to eq([ "David Thomas" ])
      expect(book.book_authors.map(&:position)).to eq([ 1 ])
    end

    it "creates no authors when the book is invalid" do
      expect { build(:book, serial_number: "bad", author_names: [ "Nobody Saved" ]).save }
        .not_to change(Author, :count)
    end

    it "joins the names for the singular author field" do
      book = create(:book, author_names: [ "Andrew Hunt", "David Thomas" ])

      expect(book.reload.author).to eq("Andrew Hunt, David Thomas")
    end

    it "removes the join rows but keeps the authors when destroyed" do
      book = create(:book, author_names: [ "Sandi Metz" ])

      expect { book.destroy! }.to change(BookAuthor, :count).by(-1).and change(Author, :count).by(0)
    end
  end

  describe "borrowing associations" do
    let(:book) { create(:book) }

    it "lists loans newest first" do
      older = create(:borrowing, :returned, book: book, borrowed_at: 20.days.ago, returned_at: 15.days.ago)
      newer = create(:borrowing, :returned, book: book, borrowed_at: 10.days.ago, returned_at: 5.days.ago)

      expect(book.reload.borrowings).to eq([ newer, older ])
    end

    it "exposes the open loan and its reader" do
      create(:borrowing, :returned, book: book)
      open_loan = create(:borrowing, book: book)

      expect(book.reload.current_borrowing).to eq(open_loan)
      expect(book.current_reader).to eq(open_loan.reader)
    end

    it "has no current loan or reader once everything is returned" do
      create(:borrowing, :returned, book: book)

      expect(book.reload.current_borrowing).to be_nil
      expect(book.current_reader).to be_nil
    end

    it "preloads the current reader for a list" do
      open_loan = create(:borrowing, book: book)

      loaded = described_class.includes(:current_reader).find(book.id)

      expect(loaded.current_reader).to eq(open_loan.reader)
    end
  end

  describe "deleting" do
    let(:book) { create(:book) }

    context "with an open loan" do
      let!(:loan) { create(:borrowing, book: book) }

      it "refuses and says why" do
        expect(book.destroy).to be(false)
        expect(book.errors[:base]).to include("Cannot delete a book while it is borrowed")
      end

      it "tags the error so the API can pick a status code" do
        book.destroy

        expect(book.errors.of_kind?(:base, :currently_borrowed)).to be(true)
      end

      it "leaves the book, its loan and its authors untouched" do
        expect { book.destroy }
          .to not_change(described_class, :count)
          .and not_change(Borrowing, :count)
          .and not_change(BookAuthor, :count)
      end
    end

    it "deletes an available book together with its returned loans" do
      create(:borrowing, :returned, book: book)

      expect { book.destroy! }.to change(described_class, :count).by(-1).and change(Borrowing, :count).by(-1)
    end

    it "can be deleted once the loan is returned" do
      loan = create(:borrowing, book: book)
      loan.update!(returned_at: Time.current)

      expect(book.reload.destroy).to be_truthy
    end
  end
end
