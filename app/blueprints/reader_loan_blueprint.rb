class ReaderLoanBlueprint < Blueprinter::Base
  fields :borrowed_at, :due_date, :returned_at

  association :book, blueprint: BookSummaryBlueprint
end
