require "rails_helper"

RSpec.describe BorrowingMailer, type: :mailer do
  let(:reader) { create(:reader, full_name: "Jan Kowalski", email: "jan.kowalski@example.com", card_number: "100001") }
  let(:book) { create(:book, title: "Oryx and Crake", serial_number: "000101", author_names: [ "Margaret Atwood" ]) }
  let(:borrowing) do
    create(
      :borrowing,
      reader: reader,
      book: book,
      borrowed_at: Time.zone.local(2026, 3, 16, 10, 0),
      due_date: Date.new(2026, 4, 15)
    )
  end

  describe "#upcoming_due_reminder" do
    let(:mail) { described_class.upcoming_due_reminder(borrowing) }

    it "sends to the reader's email address" do
      expect(mail.to).to eq([ "jan.kowalski@example.com" ])
    end

    it "includes the book title in the subject" do
      expect(mail.subject).to eq("Reminder: 'Oryx and Crake' is due in 3 days")
    end

    it "includes reader details and book details in the body" do
      body = mail.body.encoded

      expect(body).to include("Jan Kowalski")
      expect(body).to include("100001")
      expect(body).to include("Oryx and Crake")
      expect(body).to include("Margaret Atwood")
      expect(body).to include("000101")
      expect(body).to include("2026-03-16")
      expect(body).to include("2026-04-15")
    end
  end

  describe "#due_today_reminder" do
    let(:mail) { described_class.due_today_reminder(borrowing) }

    it "sends to the reader's email address" do
      expect(mail.to).to eq([ "jan.kowalski@example.com" ])
    end

    it "includes the book title in the subject" do
      expect(mail.subject).to eq("Reminder: 'Oryx and Crake' is due today")
    end

    it "includes reader details and book details in the body" do
      body = mail.body.encoded

      expect(body).to include("Jan Kowalski")
      expect(body).to include("100001")
      expect(body).to include("Oryx and Crake")
      expect(body).to include("Margaret Atwood")
      expect(body).to include("000101")
      expect(body).to include("2026-03-16")
      expect(body).to include("2026-04-15")
    end
  end
end
