# Records and response bodies behind the examples in swagger/v1/swagger.yaml.
# db/seeds.rb uses the same serial and card numbers, so the examples work in Swagger UI.
module OpenapiExamples
  SIX_DIGITS = '^\d{6}$'

  JAN = { card_number: "100001", full_name: "Jan Kowalski", email: "jan.kowalski@example.com" }.freeze
  ANNA = { card_number: "100002", full_name: "Anna Nowak", email: "anna.nowak@example.com" }.freeze

  RETURNED_LOAN = {
    borrowed_at: "2026-09-01T10:00:00.000+02:00",
    due_date: "2026-10-01",
    returned_at: "2026-09-20T15:30:00.000+02:00",
    reader: ANNA
  }.freeze

  OPEN_LOAN = {
    borrowed_at: "2026-10-20T10:00:00.000+02:00",
    due_date: "2026-11-19",
    returned_at: nil,
    reader: JAN
  }.freeze

  AVAILABLE_BOOK = {
    serial_number: "000101",
    title: "Oryx and Crake",
    status: "available",
    author: "Margaret Atwood",
    authors: [ "Margaret Atwood" ],
    borrowed: false,
    current_loan: nil
  }.freeze

  BORROWED_BOOK = {
    serial_number: "000102",
    title: "Good Omens",
    status: "borrowed",
    author: "Terry Pratchett, Neil Gaiman",
    authors: [ "Terry Pratchett", "Neil Gaiman" ],
    borrowed: true,
    current_loan: OPEN_LOAN
  }.freeze

  TWO_AUTHOR_REQUEST = {
    serial_number: "004219",
    title: "The Pragmatic Programmer",
    authors: [ "Andrew Hunt", "David Thomas" ]
  }.freeze

  ONE_AUTHOR_REQUEST = {
    serial_number: "004220",
    title: "Practical Object-Oriented Design",
    author: "Sandi Metz"
  }.freeze

  LEND_REQUEST = { status: "borrowed", card_number: JAN[:card_number] }.freeze

  SECOND_PAGE_META = { count: 3, page: 2, limit: 1, last: 3, previous: 1, next: 3 }.freeze

  UNKNOWN_READER_ERROR = { code: "unknown_reader", message: "No reader has that card number", field: "card_number" }.freeze

  # Runs at spec load, so the dry run behind rswag:specs:swaggerize still writes the example.
  # The after hook runs with the spec and fails it when the real response differs from the example.
  module Macros
    def example_response(name, summary, body)
      example "application/json", name, body, summary

      after { expect(JSON.parse(response.body)).to eq(body.as_json) }
    end

    def example_error(name, summary, code:, message:, field: nil)
      example_response name, summary, { errors: [ { code: code, message: message, field: field } ] }
    end
  end
end

RSpec.shared_context "with OpenAPI example data" do
  let(:jan) { create(:reader, **OpenapiExamples::JAN) }
  let(:anna) { create(:reader, **OpenapiExamples::ANNA) }

  # 000101: available, with one returned loan.
  let(:available_book) do
    create(:book, serial_number: "000101", title: "Oryx and Crake", author_names: [ "Margaret Atwood" ]).tap do |book|
      create(
        :borrowing,
        book: book,
        reader: anna,
        borrowed_at: Time.zone.local(2026, 9, 1, 10),
        returned_at: Time.zone.local(2026, 9, 20, 15, 30)
      )
    end
  end

  # 000102: two authors, on loan to Jan.
  let(:borrowed_book) do
    create(
      :book,
      serial_number: "000102",
      title: "Good Omens",
      author_names: [ "Terry Pratchett", "Neil Gaiman" ],
      status: :borrowed
    ).tap { |book| create(:borrowing, book: book, reader: jan, borrowed_at: Time.zone.local(2026, 10, 20, 10)) }
  end

  before { travel_to Time.zone.local(2026, 11, 2, 9) }
end

RSpec.configure do |config|
  config.extend OpenapiExamples::Macros, type: :request
end
