module Books
  class AlreadyAvailable < ConflictError
    def message = "Book is already available"
  end
end
