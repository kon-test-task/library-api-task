module Api
  module V1
    class ReadersController < ApplicationController
      rescue_from ActiveRecord::RecordNotUnique do |error|
        field = error.message.include?("email") ? :email : :card_number

        render_error(:unprocessable_content, code: "taken", message: "#{field.to_s.humanize} has already been taken", field: field)
      end

      def show
        render json: ReaderBlueprint.render(find_reader)
      end

      def create
        reader = Reader.new(reader_params)

        if reader.save
          render status: :created, json: ReaderBlueprint.render(reader)
        else
          render_record_errors(reader)
        end
      end

      def update
        reader = find_reader

        if reader.update(reader_params)
          render json: ReaderBlueprint.render(reader)
        else
          render_record_errors(reader)
        end
      end

      def destroy
        find_reader.remove!

        head :no_content
      end

      private

      def find_reader
        Reader.find_by!(card_number: params[:card_number])
      end

      # Read from the body, because the path's card_number overwrites the body's in params.
      def reader_params
        ActionController::Parameters.new(request.request_parameters).permit(:card_number, :full_name, :email)
      end
    end
  end
end
