class Borrowing < ApplicationRecord
  LOAN_PERIOD = 30.days

  belongs_to :book
  belongs_to :reader

  scope :active, -> { where(returned_at: nil) }
  scope :returned, -> { where.not(returned_at: nil) }
  scope :overdue, ->(date = Date.current) { active.where(due_date: ...date) }
  scope :due_on, ->(date) { active.where(due_date: date) }

  before_validation :set_default_dates, on: :create

  validates :borrowed_at, :due_date, presence: true
  validates :book_id, uniqueness: { conditions: -> { active }, message: "is already borrowed" }, unless: :returned_at?
  validates :returned_at, comparison: { greater_than_or_equal_to: :borrowed_at }, allow_nil: true

  private

  def set_default_dates
    self.borrowed_at ||= Time.current
    self.due_date ||= borrowed_at.to_date + LOAN_PERIOD
  end
end
