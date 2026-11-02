require "rails_helper"

RSpec.describe Author, type: :model do
  subject { build(:author) }

  it { is_expected.to validate_presence_of(:name) }

  it "squishes whitespace in the name" do
    expect(build(:author, name: "  Sandi   Metz ").name).to eq("Sandi Metz")
  end

  it "has a case-insensitive unique index at the database level" do
    create(:author, name: "Sandi Metz")

    expect { create(:author, name: "SANDI METZ") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "treats Polish names as the same author regardless of case" do
    existing = create(:author, name: "Stefan Żeromski")

    expect(described_class.find_or_create_by!(name: "STEFAN ŻEROMSKI")).to eq(existing)
  end

  it "refuses to delete an author who still has books" do
    author = create(:author, name: "Sandi Metz")
    create(:book, author_names: [ "Sandi Metz" ])

    expect(author.destroy).to be(false)
    expect(author.reload).to be_persisted
  end

  describe ".find_or_create_by!" do
    it "creates a new author" do
      expect { described_class.find_or_create_by!(name: "Sandi Metz") }.to change(described_class, :count).by(1)
    end

    it "finds an existing author regardless of case and whitespace" do
      existing = create(:author, name: "Sandi Metz")

      expect(described_class.find_or_create_by!(name: " sandi  metz ")).to eq(existing)
    end

    it "returns the winner and keeps the transaction usable when the unique index fires" do
      existing = create(:author, name: "Sandi Metz")

      described_class.transaction do
        expect(described_class.create_or_find_by!(name: "SANDI METZ")).to eq(existing)
        expect(described_class.count).to eq(1)
      end
    end

    it "raises for a blank name" do
      expect { described_class.find_or_create_by!(name: " ") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
