# Preview all emails at http://localhost:3000/rails/mailers/borrowing_mailer
class BorrowingMailerPreview < ActionMailer::Preview
  def upcoming_due_reminder
    BorrowingMailer.upcoming_due_reminder(sample_borrowing("Oryx and Crake", "Margaret Atwood", 3.days.from_now.to_date))
  end

  def due_today_reminder
    BorrowingMailer.due_today_reminder(sample_borrowing("Letters to Daughters", "Maria Skłodowska", Date.current))
  end

  private

  def sample_borrowing(title, author, due_date)
    Borrowing.active.find_by(book: Book.where(title: title)) || begin
      book = Book.new(title: title, serial_number: "000101")
      book.author_names = [ author ]
      Borrowing.new(
        book: book,
        reader: Reader.new(full_name: "Jan Kowalski", email: "jan.kowalski@example.com", card_number: "100001"),
        borrowed_at: 30.days.ago,
        due_date: due_date
      )
    end
  end
end
