module Books
  class AlreadyBorrowed < ConflictError
    def message = "Book is already borrowed"
  end
end
