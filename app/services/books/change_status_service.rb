module Books
  # Turns a status request into a Book state change. Book owns the change itself.
  class ChangeStatusService
    def initialize(book:, status:, card_number: nil)
      @book = book
      @status = status.to_s
      @card_number = card_number.to_s
    end

    def call
      case @status
      when "borrowed" then @book.borrow!(find_reader)
      when "available" then @book.give_back!
      else raise InvalidStatus
      end
    end

    private

    def find_reader
      raise MissingCardNumber if @card_number.blank?

      Reader.find_by(card_number: @card_number) || raise(UnknownReader)
    end
  end
end
