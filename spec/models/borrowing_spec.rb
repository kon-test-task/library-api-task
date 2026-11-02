require "rails_helper"

RSpec.describe Borrowing, type: :model do
  describe "default dates" do
    it "sets borrowed_at to now and due_date 30 days later" do
      travel_to Time.zone.local(2026, 3, 10, 14, 30) do
        borrowing = create(:borrowing)

        expect(borrowing.borrowed_at).to eq(Time.zone.local(2026, 3, 10, 14, 30))
        expect(borrowing.due_date).to eq(Date.new(2026, 4, 9))
      end
    end

    it "counts the 30 days from a given borrowed_at" do
      borrowing = create(:borrowing, borrowed_at: Time.zone.local(2026, 1, 20, 9))

      expect(borrowing.due_date).to eq(Date.new(2026, 2, 19))
    end

    it "keeps an explicit due_date" do
      borrowing = create(:borrowing, due_date: Date.new(2026, 12, 24))

      expect(borrowing.due_date).to eq(Date.new(2026, 12, 24))
    end
  end

  describe "returned_at" do
    it "is valid on the borrow time" do
      time = Time.zone.local(2026, 3, 10, 14, 30)

      expect(build(:borrowing, borrowed_at: time, returned_at: time)).to be_valid
    end

    it "is invalid before borrowed_at" do
      borrowing = build(:borrowing, borrowed_at: Time.zone.local(2026, 3, 10), returned_at: Time.zone.local(2026, 3, 9))

      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:returned_at]).to be_present
    end

    it "is guarded by a database CHECK constraint" do
      borrowing = create(:borrowing, borrowed_at: Time.zone.local(2026, 3, 10))

      expect { borrowing.update_column(:returned_at, Time.zone.local(2026, 3, 9)) }
        .to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "open loan index" do
    let(:book) { create(:book) }

    before { create(:borrowing, book: book) }

    it "blocks a second open loan at the database level" do
      second = build(:borrowing, book: book, borrowed_at: Time.current, due_date: Date.current)

      expect { second.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "reports a second open loan as a validation error" do
      second = build(:borrowing, book: book)

      expect(second.save).to be(false)
      expect(second.errors[:book_id]).to include("is already borrowed")
    end

    it "lets the open loan itself save again" do
      expect(book.current_borrowing.update(due_date: Date.current)).to be(true)
    end

    it "does not count returned loans against a new one" do
      other_book = create(:book)
      create(:borrowing, :returned, book: other_book)

      expect(build(:borrowing, book: other_book)).to be_valid
    end

    it "allows a new loan once the first is returned" do
      book.current_borrowing.update!(returned_at: Time.current)

      expect(create(:borrowing, book: book)).to be_persisted
    end
  end

  describe "scopes" do
    let!(:open_loan) { create(:borrowing, due_date: Date.new(2026, 3, 20)) }
    let!(:returned_loan) { create(:borrowing, :returned, due_date: Date.new(2026, 3, 1)) }
    let!(:overdue_loan) { create(:borrowing, due_date: Date.new(2026, 3, 9)) }

    it "splits active from returned" do
      expect(described_class.active).to contain_exactly(open_loan, overdue_loan)
      expect(described_class.returned).to contain_exactly(returned_loan)
    end

    it "treats open loans past the due date as overdue, and not on the due date" do
      expect(described_class.overdue(Date.new(2026, 3, 10))).to contain_exactly(overdue_loan)
      expect(described_class.overdue(Date.new(2026, 3, 9))).to be_empty
    end

    it "defaults overdue to today" do
      travel_to Time.zone.local(2026, 3, 21) do
        expect(described_class.overdue).to contain_exactly(open_loan, overdue_loan)
      end
    end

    it "finds open loans by due date" do
      expect(described_class.due_on(Date.new(2026, 3, 20))).to contain_exactly(open_loan)
    end

    it "leaves returned loans out of due_on" do
      expect(described_class.due_on(Date.new(2026, 3, 1))).to be_empty
    end
  end
end
