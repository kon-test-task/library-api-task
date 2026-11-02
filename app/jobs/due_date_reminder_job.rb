class DueDateReminderJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    target_date = date.is_a?(String) ? Date.parse(date) : date

    send_upcoming_reminders(target_date)
    send_due_reminders(target_date)
  end

  private

  def send_upcoming_reminders(date)
    Borrowing.pending_upcoming_reminder(date).includes(:reader, :book).find_each do |borrowing|
      borrowing.update!(upcoming_reminder_sent_at: Time.current)
      BorrowingMailer.upcoming_due_reminder(borrowing).deliver_later
      log_reminder(borrowing, "upcoming")
    end
  end

  def send_due_reminders(date)
    Borrowing.pending_due_reminder(date).includes(:reader, :book).find_each do |borrowing|
      borrowing.update!(due_reminder_sent_at: Time.current)
      BorrowingMailer.due_today_reminder(borrowing).deliver_later
      log_reminder(borrowing, "due_today")
    end
  end

  def log_reminder(borrowing, kind)
    Rails.logger.info "[Reminder] #{kind} reminder to #{borrowing.reader.email} for book #{borrowing.book.serial_number}"
  end
end
