module Books
  class InvalidStatus < InvalidInputError
    def message = "Status must be borrowed or available"
    def field = :status
  end
end
