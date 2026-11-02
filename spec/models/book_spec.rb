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
end
