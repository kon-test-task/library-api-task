# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  loan_schema = {
    type: :object,
    required: %w[borrowed_at due_date returned_at reader],
    properties: {
      borrowed_at: { type: :string, format: 'date-time' },
      due_date: { type: :string, format: :date },
      returned_at: { type: :string, format: 'date-time', nullable: true },
      reader: { '$ref' => '#/components/schemas/reader' }
    }
  }

  book_properties = {
    serial_number: { type: :string },
    title: { type: :string },
    status: { type: :string, enum: %w[available borrowed] },
    author: { type: :string },
    authors: { type: :array, items: { type: :string } },
    borrowed: { type: :boolean },
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
        title: 'API V1',
        version: 'v1'
      },
      paths: {},
      components: {
        schemas: {
          reader: {
            type: :object,
            required: %w[card_number full_name email],
            properties: {
              card_number: { type: :string },
              full_name: { type: :string },
              email: { type: :string }
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
              count: { type: :integer },
              page: { type: :integer },
              limit: { type: :integer },
              last: { type: :integer },
              previous: { type: :integer },
              next: { type: :integer }
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
                    code: { type: :string },
                    message: { type: :string },
                    field: { type: :string, nullable: true }
                  }
                }
              }
            }
          }
        }
      },
      servers: [
        {
          url: 'https://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'www.example.com'
            }
          }
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
