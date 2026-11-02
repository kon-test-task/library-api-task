module Api
  module V1
    class ReaderBooksController < ApplicationController
      include Paginated

      def index
        reader = Reader.find_by!(card_number: params[:reader_card_number])
        loans = reader.borrowings.includes(book: :authors).order(borrowed_at: :desc, id: :desc)
        loans = loans.active unless params[:include_returned] == "true"
        records, meta = paginate(loans)

        render json: { reader: ReaderBlueprint.render_as_hash(reader), loans: ReaderLoanBlueprint.render_as_hash(records), meta: meta }
      end
    end
  end
end
