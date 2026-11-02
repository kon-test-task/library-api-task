module Books
  class MissingCardNumber < InvalidInputError
    def message = "card_number is required to borrow a book"
    def field = :card_number
  end
end
