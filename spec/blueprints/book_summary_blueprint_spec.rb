require "rails_helper"

RSpec.describe BookSummaryBlueprint, type: :model do
  let(:book) { create(:book, author_names: [ "Andrew Hunt", "David Thomas" ]) }

  describe "default serialization" do
    subject(:serialized_book) { described_class.render_as_hash(book) }

    it "includes only the summary fields" do
      expect(serialized_book).to eq(
        serial_number: book.serial_number,
        title: book.title,
        author: "Andrew Hunt, David Thomas"
      )
    end
  end
end
