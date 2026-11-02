class Book < ApplicationRecord
  enum :status, { available: 0, borrowed: 1 }

  has_many :book_authors, -> { order(:position) }, dependent: :destroy, inverse_of: :book
  has_many :authors, through: :book_authors

  normalizes :serial_number, with: ->(value) { value.strip }

  validates :serial_number, format: { with: /\A\d{6}\z/, message: "must be a 6-digit number" }, uniqueness: true
  validates :title, presence: true
  validate :must_have_an_author

  after_save :save_author_names

  # Takes one name or a list. A string stays one author, because "Tolkien, J.R.R." is one person.
  def author_names=(names)
    @author_names = Array(names)
      .filter_map { |name| Author.normalize_value_for(:name, name.to_s).presence }
      .uniq(&:downcase)
  end

  def author_names
    @author_names || authors.map(&:name)
  end

  def author
    author_names.join(", ")
  end

  private

  def must_have_an_author
    errors.add(:authors, "must include at least one author") if author_names.empty?
  end

  def save_author_names
    return unless @author_names

    book_authors.destroy_all
    @author_names.each.with_index(1) do |name, position|
      book_authors.create!(author: Author.find_or_create_by!(name: name), position: position)
    end

    @author_names = nil
    book_authors.reset
    authors.reset
  end
end
