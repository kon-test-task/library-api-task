require "rails_helper"

RSpec.describe ReaderBlueprint, type: :model do
  let(:reader) { create(:reader) }

  describe "default serialization" do
    subject(:serialized_reader) { described_class.render_as_hash(reader) }

    it "includes only the reader fields" do
      expect(serialized_reader).to eq(
        card_number: reader.card_number,
        full_name: reader.full_name,
        email: reader.email
      )
    end
  end
end
