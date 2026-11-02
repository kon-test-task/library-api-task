module Readers
  class HasLoans < ConflictError
    def message = "Reader has loans and cannot be deleted"
  end
end
