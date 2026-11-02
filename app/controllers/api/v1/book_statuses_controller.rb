module Api
  module V1
    class BookStatusesController < ApplicationController
      def update
        book = Book.find_by!(serial_number: params[:serial_number])

        Books::ChangeStatusService.new(book: book, status: params.require(:status), card_number: params[:card_number]).call

        render json: BookBlueprint.render(Book.with_history.find(book.id), view: :history)
      end
    end
  end
end
