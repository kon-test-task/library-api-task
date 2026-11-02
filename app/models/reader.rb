class Reader < ApplicationRecord
  has_many :borrowings, dependent: :restrict_with_error, inverse_of: :reader

  normalizes :card_number, with: ->(value) { value.strip }
  normalizes :full_name, with: ->(value) { value.squish }
  normalizes :email, with: ->(value) { value.strip.downcase }

  validates :card_number, format: { with: /\A\d{6}\z/, message: "must be a 6-digit number" }, uniqueness: true
  validates :full_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true

  # Past loans count too, because each one shows who borrowed a book (D38).
  # The foreign key catches a loan another request creates at the same moment.
  def remove!
    with_lock do
      raise Readers::HasLoans if borrowings.exists?

      destroy!
    end
  rescue ActiveRecord::InvalidForeignKey
    raise Readers::HasLoans
  end
end
