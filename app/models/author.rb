class Author < ApplicationRecord
  has_many :book_authors, dependent: :restrict_with_error, inverse_of: :author
  has_many :books, through: :book_authors

  normalizes :name, with: ->(value) { value.squish }

  # The citext unique index enforces uniqueness. A uniqueness validation here would raise
  # RecordInvalid during a race, which find_or_create_by! does not rescue.
  validates :name, presence: true
end
