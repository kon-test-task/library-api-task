class BookBlueprint < Blueprinter::Base
  fields :serial_number, :title, :status, :author

  field(:authors) { |book| book.author_names }
  field(:borrowed) { |book| book.borrowed? }

  view :list do
    association :current_borrowing, name: :current_loan, blueprint: BorrowingBlueprint
  end

  view :history do
    include_view :list
    association :borrowings, name: :loans, blueprint: BorrowingBlueprint
  end
end
