module Api
  module V1
    class BooksController < ApplicationController
      include Pagy::Method

      MAX_LIMIT = 100
      PAGINATION_KEYS = %i[count page limit last previous next].freeze

      before_action :refuse_both_author_fields, only: :create

      rescue_from Pagy::OptionError do |error|
        render_error(:unprocessable_content, code: "invalid_pagination", message: "#{error.option} must be at least 1", field: error.option)
      end

      def index
        books = Book.includes(:authors, current_borrowing: :reader).order(:serial_number)
        books = books.by_author(params[:author].to_s) if params[:author].present?
        pagination, records = pagy(books, client_limit: MAX_LIMIT)

        render json: BookBlueprint.render(records, view: :list, root: :books, meta: pagination.data_hash(data_keys: PAGINATION_KEYS))
      end

      def show
        book = Book.includes(:authors, current_borrowing: :reader, borrowings: :reader)
          .find_by!(serial_number: params[:serial_number])

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
        book = Book.find_by!(serial_number: params[:serial_number])

        if book.destroy
          head :no_content
        else
          render_record_errors(book, status: :conflict)
        end
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
