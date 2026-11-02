class Book < ApplicationRecord
  enum :status, { available: 0, borrowed: 1 }

  has_many :book_authors, -> { order(:position) }, dependent: :destroy, inverse_of: :book
  has_many :authors, through: :book_authors
  has_many :borrowings, -> { order(borrowed_at: :desc) }, dependent: :destroy, inverse_of: :book
  has_one :current_borrowing, -> { active }, class_name: "Borrowing", inverse_of: :book
  has_one :current_reader, through: :current_borrowing, source: :reader

  before_destroy :refuse_while_borrowed, prepend: true

  scope :with_history, -> { includes(:authors, current_borrowing: :reader, borrowings: :reader) }
  scope :by_author, ->(fragment) do
    where(
      BookAuthor.joins(:author)
        .where("book_authors.book_id = books.id")
        .where("authors.name ILIKE ?", "%#{sanitize_sql_like(fragment)}%")
        .arel.exists
    )
  end

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

  # with_lock opens a transaction and reloads the book with SELECT ... FOR UPDATE,
  # so lend, return and remove on the same book run one at a time.
  # Each decides from the open loan, which the partial unique index keeps to at most one.
  def borrow!(reader)
    with_lock do
      raise Books::AlreadyBorrowed if current_borrowing

      borrowings.create!(reader: reader)
      borrowed!
    end
  rescue ActiveRecord::RecordNotUnique
    raise Books::AlreadyBorrowed
  end

  def give_back!
    with_lock do
      loan = current_borrowing
      raise Books::AlreadyAvailable unless loan

      loan.update!(returned_at: Time.current)
      available!
    end
  end

  def remove!
    with_lock do
      raise Books::AlreadyBorrowed if current_borrowing

      destroy!
    end
  end

  private

  # Stops a direct destroy from a console or seed. Book#remove! is the path that takes the row lock.
  def refuse_while_borrowed
    return unless current_borrowing

    errors.add(:base, "Cannot delete a book while it is borrowed")
    throw :abort
  end

  def must_have_an_author
    errors.add(:authors, :blank, message: "must include at least one author") if author_names.empty?
  end

  def save_author_names
    return unless @author_names

    # Sorted inserts stop two requests creating the same new authors in opposite orders from deadlocking.
    authors_by_name = @author_names.sort_by(&:downcase).to_h { |name| [ name, Author.find_or_create_by!(name: name) ] }

    book_authors.destroy_all
    @author_names.each.with_index(1) do |name, position|
      book_authors.create!(author: authors_by_name.fetch(name), position: position)
    end

    @author_names = nil
    book_authors.reset
    authors.reset
  end
end
