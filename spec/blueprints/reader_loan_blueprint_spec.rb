require "rails_helper"

RSpec.describe ReaderLoanBlueprint, type: :model do
  before { freeze_time }

  let(:book) { create(:book) }
  let(:loan) { create(:borrowing, book: book) }

  describe "default serialization" do
    subject(:serialized_loan) { described_class.render_as_hash(loan) }

    it "includes the loan dates and the book summary, without the reader" do
      expect(serialized_loan).to eq(
        borrowed_at: Time.current,
        due_date: 30.days.from_now.to_date,
        returned_at: nil,
        book: BookSummaryBlueprint.render_as_hash(book)
      )
    end

    context "when the book has come back" do
      let(:loan) { create(:borrowing, :returned, book: book) }

      it "includes the return time" do
        expect(serialized_loan[:returned_at]).to eq(loan.returned_at)
      end
    end
  end

  describe "JSON output" do
    subject(:json) { JSON.parse(described_class.render(loan)) }

    it "writes timestamps as ISO 8601" do
      expect(json["borrowed_at"]).to eq(Time.current.iso8601(3))
    end

    it "writes the due date as a plain date" do
      expect(json["due_date"]).to eq(30.days.from_now.to_date.iso8601)
    end
  end
end
