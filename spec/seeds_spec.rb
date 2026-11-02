require "swagger_helper"

RSpec.describe "Seed data" do
  before { Rails.application.load_seed }

  it "adds nothing on a second run" do
    expect { Rails.application.load_seed }
      .to not_change(Reader, :count)
      .and not_change(Book, :count)
      .and not_change(Borrowing, :count)
  end

  it "matches the readers and books in the OpenAPI examples" do
    [ OpenapiExamples::JAN, OpenapiExamples::ANNA ].each do |reader|
      expect(Reader.find_by!(card_number: reader[:card_number])).to have_attributes(reader)
    end

    [ OpenapiExamples::AVAILABLE_BOOK, OpenapiExamples::BORROWED_BOOK ].each do |book|
      expect(Book.find_by!(serial_number: book[:serial_number]))
        .to have_attributes(book.slice(:title, :status, :author))
    end
  end

  it "keeps the delete example available and the create examples free" do
    expect(Book.find_by!(serial_number: "000103")).to be_available
    expect(Book.where(serial_number: %w[004219 004220])).to be_empty
    expect(Reader.where(card_number: [ OpenapiExamples::NEW_READER[:card_number], OpenapiExamples::NEW_CARD_REQUEST[:card_number] ])).to be_empty
  end

  it "keeps the history of the available book" do
    loan = Book.find_by!(serial_number: "000101").borrowings.sole

    expect(loan.reader.card_number).to eq(OpenapiExamples::ANNA[:card_number])
    expect(loan.returned_at).to be_present
  end

  it "keeps the status of each book in step with its open loan" do
    Book.includes(:current_borrowing).find_each do |book|
      expect(book.borrowed?).to eq(book.current_borrowing.present?)
    end
  end

  it "seeds one loan due in 3 days, one due today and one overdue" do
    expect(Borrowing.due_on(3.days.from_now.to_date).map { |loan| loan.book.serial_number }).to eq([ "000104" ])
    expect(Borrowing.due_on(Date.current).map { |loan| loan.book.serial_number }).to eq([ "000105" ])
    expect(Borrowing.overdue.map { |loan| loan.book.serial_number }).to eq([ "000106" ])
  end

  it "gives the reminder job exactly two mails to send" do
    expect { DueDateReminderJob.perform_now }.to have_enqueued_mail(BorrowingMailer).exactly(2).times
  end
end
