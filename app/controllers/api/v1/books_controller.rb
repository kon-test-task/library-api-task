module Api
  module V1
    class BooksController < ApplicationController
      include Paginated

      before_action :refuse_both_author_fields, only: :create

      def index
        books = Book.includes(:authors, current_borrowing: :reader).order(:serial_number)
        books = books.by_author(params[:author].to_s) if params[:author].present?
        books = books.by_title(params[:title].to_s) if params[:title].present?
        records, meta = paginate(books)

        render json: BookBlueprint.render(records, view: :list, root: :books, meta: meta)
      end

      def show
        book = Book.with_history.find_by!(serial_number: params[:serial_number])

        render json: BookBlueprint.render(book, view: :history)
      end

      def create
        book = Book.new(book_params)

        if book.save
          render status: :created, json: BookBlueprint.render(book, view: :list)
        else
          render_record_errors(book)
        end
      rescue ActiveRecord::RecordNotUnique
        render_error(:unprocessable_content, code: "taken", message: "Serial number has already been taken", field: :serial_number)
      end

      def destroy
        Book.find_by!(serial_number: params[:serial_number]).remove!

        head :no_content
      end

      private

      def book_params
        permitted = params.permit(:serial_number, :title, :author, authors: [])

        permitted.slice(:serial_number, :title).merge(author_names: permitted[:authors] || permitted[:author])
      end

      def refuse_both_author_fields
        return unless params.key?(:author) && params.key?(:authors)

        render_error(:unprocessable_content, code: "ambiguous_authors", message: "Send either author or authors, not both", field: :authors)
      end
    end
  end
end
