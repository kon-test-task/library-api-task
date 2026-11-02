# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/openapi_examples'

RSpec.configure do |config|
  loan_schema = {
    type: :object,
    required: %w[borrowed_at due_date returned_at reader],
    properties: {
      borrowed_at: { type: :string, format: 'date-time', example: OpenapiExamples::RETURNED_LOAN[:borrowed_at] },
      due_date: { type: :string, format: :date, description: '30 days after the borrow date', example: OpenapiExamples::RETURNED_LOAN[:due_date] },
      returned_at: { type: :string, format: 'date-time', nullable: true, description: 'Null while the loan is open', example: OpenapiExamples::RETURNED_LOAN[:returned_at] },
      reader: { '$ref' => '#/components/schemas/reader' }
    }
  }

  book_properties = {
    serial_number: { type: :string, pattern: OpenapiExamples::SIX_DIGITS, description: 'Six digits, leading zeros included', example: OpenapiExamples::BORROWED_BOOK[:serial_number] },
    title: { type: :string, example: OpenapiExamples::BORROWED_BOOK[:title] },
    status: { type: :string, enum: %w[available borrowed], example: OpenapiExamples::BORROWED_BOOK[:status] },
    author: { type: :string, description: 'All authors joined with a comma', example: OpenapiExamples::BORROWED_BOOK[:author] },
    authors: { type: :array, items: { type: :string }, description: 'Authors in display order', example: OpenapiExamples::BORROWED_BOOK[:authors] },
    borrowed: { type: :boolean, example: OpenapiExamples::BORROWED_BOOK[:borrowed] },
    current_loan: loan_schema.merge(nullable: true)
  }

  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Library API',
        description: 'Library staff use this API to track books, readers and loans.',
        version: 'v1'
      },
      paths: {},
      components: {
        schemas: {
          reader: {
            type: :object,
            required: %w[card_number full_name email],
            properties: {
              card_number: { type: :string, pattern: OpenapiExamples::SIX_DIGITS, description: 'Six digits, leading zeros included', example: OpenapiExamples::ANNA[:card_number] },
              full_name: { type: :string, example: OpenapiExamples::ANNA[:full_name] },
              email: { type: :string, format: :email, example: OpenapiExamples::ANNA[:email] }
            }
          },
          loan: loan_schema,
          book: {
            type: :object,
            required: book_properties.keys.map(&:to_s),
            properties: book_properties
          },
          book_with_history: {
            type: :object,
            required: book_properties.keys.map(&:to_s) + %w[loans],
            properties: book_properties.merge(loans: { type: :array, items: { '$ref' => '#/components/schemas/loan' } })
          },
          pagination: {
            type: :object,
            required: %w[count page limit last],
            properties: {
              count: { type: :integer, description: 'Books across all pages', example: OpenapiExamples::SECOND_PAGE_META[:count] },
              page: { type: :integer, example: OpenapiExamples::SECOND_PAGE_META[:page] },
              limit: { type: :integer, example: OpenapiExamples::SECOND_PAGE_META[:limit] },
              last: { type: :integer, description: 'Number of the last page', example: OpenapiExamples::SECOND_PAGE_META[:last] },
              previous: { type: :integer, description: 'Left out on the first page', example: OpenapiExamples::SECOND_PAGE_META[:previous] },
              next: { type: :integer, description: 'Left out on the last page', example: OpenapiExamples::SECOND_PAGE_META[:next] }
            }
          },
          errors: {
            type: :object,
            required: %w[errors],
            properties: {
              errors: {
                type: :array,
                items: {
                  type: :object,
                  required: %w[code message field],
                  properties: {
                    code: { type: :string, example: OpenapiExamples::UNKNOWN_READER_ERROR[:code] },
                    message: { type: :string, example: OpenapiExamples::UNKNOWN_READER_ERROR[:message] },
                    field: { type: :string, nullable: true, description: 'Null when the error is not about one field', example: OpenapiExamples::UNKNOWN_READER_ERROR[:field] }
                  }
                }
              }
            }
          }
        }
      },
      servers: [
        {
          url: 'http://localhost:3000'
        }
      ]
    }
  }

  # Fail a spec when a response has a field its schema does not list.
  config.openapi_no_additional_properties = true

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
