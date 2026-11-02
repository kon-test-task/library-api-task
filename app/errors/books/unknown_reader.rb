module Books
  class UnknownReader < InvalidInputError
    def message = "No reader has that card number"
    def field = :card_number
  end
end
