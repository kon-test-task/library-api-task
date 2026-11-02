class AddReminderTrackingToBorrowings < ActiveRecord::Migration[8.1]
  def change
    add_column :borrowings, :upcoming_reminder_sent_at, :datetime
    add_column :borrowings, :due_reminder_sent_at, :datetime
  end
end
