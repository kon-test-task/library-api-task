require "swagger_helper"

RSpec.describe "Readers API", type: :request do
  include_context "with OpenAPI example data"

  reader_properties = {
    card_number: { type: :string, pattern: OpenapiExamples::SIX_DIGITS, description: "Six digits, leading zeros included", example: OpenapiExamples::NEW_READER[:card_number] },
    full_name: { type: :string, example: OpenapiExamples::NEW_READER[:full_name] },
    email: { type: :string, format: :email, example: OpenapiExamples::NEW_READER[:email] }
  }

  path "/api/v1/readers" do
    post "Adds a reader" do
      tags "Readers"
      consumes "application/json"
      produces "application/json"
      parameter name: :reader_body, in: :body, required: true, schema: {
        type: :object, required: %w[card_number full_name email], properties: reader_properties
      }
      request_body_example name: :new_reader, summary: "A new reader", value: OpenapiExamples::NEW_READER

      response "201", "reader created" do
        schema "$ref" => "#/components/schemas/reader"

        example_response :created, "The new reader", OpenapiExamples::NEW_READER

        let(:reader_body) { OpenapiExamples::NEW_READER }

        run_test!
      end

      response "400", "the request could not be read" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_json, "A body that does not parse", code: "invalid_json", message: "Request body is not valid JSON"

        let(:reader_body) { double(to_json: '{"email":') }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_response :invalid_fields, "A bad card number, no name and a bad email", {
          errors: [
            { code: "invalid", message: "Card number must be a 6-digit number", field: "card_number" },
            { code: "blank", message: "Full name can't be blank", field: "full_name" },
            { code: "invalid", message: "Email is invalid", field: "email" }
          ]
        }

        let(:reader_body) { { card_number: "12a456", full_name: "", email: "not-an-email" } }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :taken, "An email another reader uses", code: "taken", message: "Email has already been taken", field: "email"

        let(:reader_body) { OpenapiExamples::NEW_READER.merge(email: jan.email) }

        run_test!
      end

      bad_request_response { let(:reader_body) { double(to_json: %({"full_name":"\xE0"})) } }

      internal_error_response do
        let(:reader_body) { OpenapiExamples::NEW_READER }

        before { allow(Reader).to receive(:new).and_raise("boom") }
      end
    end
  end

  path "/api/v1/readers/{card_number}" do
    get "Shows a reader" do
      tags "Readers"
      produces "application/json"
      parameter name: :card_number, in: :path, type: :string, description: "Six-digit library card number", example: OpenapiExamples::JAN[:card_number]

      response "200", "reader found" do
        schema "$ref" => "#/components/schemas/reader"

        example_response :reader, "A registered reader", OpenapiExamples::JAN

        let(:card_number) { jan.card_number }

        run_test!
      end

      response "404", "no reader with that card number" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :not_found, "An unknown card number", code: "not_found", message: "Reader not found"

        let(:card_number) { "999999" }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_characters, "A null byte in the card number",
                      code: "invalid_characters", message: "Parameters must not contain null bytes"

        let(:card_number) { "a%00b" }

        run_test!
      end

      bad_request_response { let(:card_number) { "100001?page=%E0" } }

      internal_error_response do
        let(:card_number) { "100001" }

        before { allow(Reader).to receive(:find_by!).and_raise("boom") }
      end
    end

    patch "Updates a reader, including their card number" do
      tags "Readers"
      consumes "application/json"
      produces "application/json"
      parameter name: :card_number, in: :path, type: :string, description: "The reader's current card number", example: OpenapiExamples::NEW_READER[:card_number]
      parameter name: :reader_body, in: :body, required: true, schema: { type: :object, properties: reader_properties }
      request_body_example name: :rename, summary: "Change the name", value: OpenapiExamples::RENAME_REQUEST
      request_body_example name: :new_card, summary: "Replace a lost card. The old number then returns 404", value: OpenapiExamples::NEW_CARD_REQUEST

      let(:existing) { create(:reader, **OpenapiExamples::NEW_READER) }
      let(:card_number) { existing.card_number }

      response "200", "reader updated" do
        schema "$ref" => "#/components/schemas/reader"

        example_response :renamed, "The reader with a new name", OpenapiExamples::NEW_READER.merge(OpenapiExamples::RENAME_REQUEST)

        let(:reader_body) { OpenapiExamples::RENAME_REQUEST }

        run_test!
      end

      response "200", "reader updated" do
        schema "$ref" => "#/components/schemas/reader"

        example_response :new_card, "The reader with a new card number", OpenapiExamples::NEW_READER.merge(OpenapiExamples::NEW_CARD_REQUEST)

        let(:reader_body) { OpenapiExamples::NEW_CARD_REQUEST }

        run_test!
      end

      response "400", "the request could not be read" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_json, "A body that does not parse", code: "invalid_json", message: "Request body is not valid JSON"

        let(:reader_body) { double(to_json: '{"email":') }

        run_test!
      end

      response "404", "no reader with that card number" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :not_found, "An unknown card number", code: "not_found", message: "Reader not found"

        let(:card_number) { "999999" }
        let(:reader_body) { OpenapiExamples::RENAME_REQUEST }

        run_test!
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :taken, "A card number another reader has", code: "taken", message: "Card number has already been taken", field: "card_number"

        let(:reader_body) { { card_number: jan.card_number } }

        run_test!
      end

      bad_request_response do
        let(:card_number) { "100004?page=%E0" }
        let(:reader_body) { OpenapiExamples::RENAME_REQUEST }
      end

      internal_error_response do
        let(:card_number) { "100004" }
        let(:reader_body) { OpenapiExamples::RENAME_REQUEST }

        before { allow(Reader).to receive(:find_by!).and_raise("boom") }
      end
    end

    delete "Deletes a reader who has no loans" do
      tags "Readers"
      produces "application/json"
      parameter name: :card_number, in: :path, type: :string, description: "Six-digit library card number", example: OpenapiExamples::NEW_READER[:card_number]

      response "204", "reader deleted" do
        let(:card_number) { create(:reader, **OpenapiExamples::NEW_READER).card_number }

        run_test! do
          expect(Reader.exists?(card_number: OpenapiExamples::NEW_READER[:card_number])).to be(false)
        end
      end

      response "404", "no reader with that card number" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :not_found, "An unknown card number", code: "not_found", message: "Reader not found"

        let(:card_number) { "999999" }

        run_test!
      end

      response "409", "the reader has loans" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :has_loans, "A reader with an open or returned loan", code: "has_loans", message: "Reader has loans and cannot be deleted"

        let(:card_number) { borrowed_book && jan.card_number }

        run_test! do
          expect(Reader.exists?(card_number: "100001")).to be(true)
        end
      end

      response "422", "invalid input" do
        schema "$ref" => "#/components/schemas/errors"

        example_error :invalid_characters, "A null byte in the card number", code: "invalid_characters", message: "Parameters must not contain null bytes"

        let(:card_number) { "a%00b" }

        run_test!
      end

      bad_request_response { let(:card_number) { "100004?page=%E0" } }

      internal_error_response do
        let(:card_number) { "100004" }

        before { allow(Reader).to receive(:find_by!).and_raise("boom") }
      end
    end
  end
end
