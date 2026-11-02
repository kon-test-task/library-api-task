class BorrowingMailer < ApplicationMailer
  def upcoming_due_reminder(borrowing)
    @borrowing = borrowing
    @reader = borrowing.reader
    @book = borrowing.book
    @due_date = borrowing.due_date

    mail(
      to: @reader.email,
      subject: "Reminder: '#{@book.title}' is due in 3 days"
    )
  end

  def due_today_reminder(borrowing)
    @borrowing = borrowing
    @reader = borrowing.reader
    @book = borrowing.book
    @due_date = borrowing.due_date

    mail(
      to: @reader.email,
      subject: "Reminder: '#{@book.title}' is due today"
    )
  end
end
