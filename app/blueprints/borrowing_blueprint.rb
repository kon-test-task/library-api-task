class BorrowingBlueprint < Blueprinter::Base
  fields :borrowed_at, :due_date, :returned_at

  association :reader, blueprint: ReaderBlueprint
end
