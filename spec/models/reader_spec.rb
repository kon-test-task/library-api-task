require "rails_helper"

RSpec.describe Reader, type: :model do
  subject { build(:reader) }

  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_uniqueness_of(:card_number).ignoring_case_sensitivity }
  it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }

  describe "card_number" do
    it "accepts six digits and keeps leading zeros" do
      reader = create(:reader, card_number: "004219")

      expect(reader.reload.card_number).to eq("004219")
    end

    [ "12345", "1234567", "12a456", "", nil ].each do |value|
      it "rejects #{value.inspect}" do
        reader = build(:reader, card_number: value)

        expect(reader).not_to be_valid
        expect(reader.errors[:card_number]).to include("must be a 6-digit number")
      end
    end

    it "is guarded by a database CHECK constraint" do
      reader = create(:reader)

      expect { reader.update_column(:card_number, "12a456") }.to raise_error(ActiveRecord::CheckViolation)
    end
  end

  describe "email" do
    it "strips and downcases" do
      expect(build(:reader, email: "  Ada@Example.COM ").email).to eq("ada@example.com")
    end

    it "rejects the same address in a different case" do
      create(:reader, email: "ada@example.com")
      duplicate = build(:reader, email: "ADA@example.com")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")
    end

    it "has a unique index at the database level" do
      create(:reader, email: "ada@example.com")
      duplicate = build(:reader, email: "ada@example.com")

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    [ "not-an-email", "", nil ].each do |value|
      it "rejects #{value.inspect}" do
        expect(build(:reader, email: value)).not_to be_valid
      end
    end
  end

  it "squishes whitespace in the full name" do
    expect(build(:reader, full_name: " Ada   Lovelace ").full_name).to eq("Ada Lovelace")
  end
end
