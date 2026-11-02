require "rails_helper"

RSpec.describe DueDateReminderJob, type: :job do
  include ActiveJob::TestHelper

  let(:run_date) { Date.new(2026, 5, 10) }

  describe "#perform" do
    let!(:due_in_3_days) { create(:borrowing, due_date: run_date + 3.days) }
    let!(:due_today) { create(:borrowing, due_date: run_date) }
    let!(:due_in_4_days) { create(:borrowing, due_date: run_date + 4.days) }
    let!(:due_in_10_days) { create(:borrowing, due_date: run_date + 10.days) }
    let!(:returned_loan) { create(:borrowing, :returned, due_date: run_date + 3.days) }
    let!(:returned_today) { create(:borrowing, :returned, due_date: run_date) }

    it "sends the 3-day mail to loans due in 3 days and the due-day mail to loans due today, and nothing else" do
      travel_to run_date.to_time do
        expect {
          perform_enqueued_jobs { described_class.perform_now }
        }.to change { ActionMailer::Base.deliveries.count }.by(2)

        recipients = ActionMailer::Base.deliveries.last(2).map(&:to).flatten
        expect(recipients).to contain_exactly(due_in_3_days.reader.email, due_today.reader.email)

        subjects = ActionMailer::Base.deliveries.last(2).map(&:subject)
        expect(subjects).to include(
          "Reminder: '#{due_in_3_days.book.title}' is due in 3 days",
          "Reminder: '#{due_today.book.title}' is due today"
        )
      end
    end

    it "stamps the reminder timestamps when enqueuing" do
      travel_to run_date.to_time do
        described_class.perform_now

        expect(due_in_3_days.reload.upcoming_reminder_sent_at).to be_present
        expect(due_in_3_days.due_reminder_sent_at).to be_nil

        expect(due_today.reload.due_reminder_sent_at).to be_present
        expect(due_today.upcoming_reminder_sent_at).to be_nil
      end
    end

    it "logs a reminder line with recipient email, book serial and kind" do
      allow(Rails.logger).to receive(:info).and_call_original

      travel_to run_date.to_time do
        described_class.perform_now

        expect(Rails.logger).to have_received(:info).with(
          "[Reminder] upcoming reminder to #{due_in_3_days.reader.email} for book #{due_in_3_days.book.serial_number}"
        )
        expect(Rails.logger).to have_received(:info).with(
          "[Reminder] due_today reminder to #{due_today.reader.email} for book #{due_today.book.serial_number}"
        )
      end
    end

    it "sends no mail to returned loans" do
      travel_to run_date.to_time do
        due_in_3_days.update!(upcoming_reminder_sent_at: Time.current)
        due_today.update!(due_reminder_sent_at: Time.current)

        expect {
          perform_enqueued_jobs { described_class.perform_now }
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    it "sends nothing on a second run on the same day" do
      travel_to run_date.to_time do
        described_class.perform_now

        expect {
          perform_enqueued_jobs { described_class.perform_now }
        }.not_to change { ActionMailer::Base.deliveries.count }
      end
    end

    it "sends missed reminders after worker downtime" do
      missed_upcoming = create(:borrowing, due_date: run_date + 1.day)
      missed_due = create(:borrowing, due_date: run_date - 1.day)

      travel_to run_date.to_time do
        due_in_3_days.update!(upcoming_reminder_sent_at: Time.current)
        due_today.update!(due_reminder_sent_at: Time.current)

        expect {
          perform_enqueued_jobs { described_class.perform_now }
        }.to change { ActionMailer::Base.deliveries.count }.by(2)

        expect(missed_upcoming.reload.upcoming_reminder_sent_at).to be_present
        expect(missed_due.reload.due_reminder_sent_at).to be_present
      end
    end

    it "accepts an explicit date object" do
      expect {
        perform_enqueued_jobs { described_class.perform_now(run_date) }
      }.to change { ActionMailer::Base.deliveries.count }.by(2)
    end
  end
end
