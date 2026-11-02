class Reader < ApplicationRecord
  has_many :borrowings, dependent: :restrict_with_error, inverse_of: :reader

  normalizes :card_number, with: ->(value) { value.strip }
  normalizes :full_name, with: ->(value) { value.squish }
  normalizes :email, with: ->(value) { value.strip.downcase }

  validates :card_number, format: { with: /\A\d{6}\z/, message: "must be a 6-digit number" }, uniqueness: true
  validates :full_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
end
