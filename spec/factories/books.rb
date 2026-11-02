FactoryBot.define do
  factory :book do
    sequence(:serial_number) { |n| format("%06d", n) }
    sequence(:title) { |n| "Book #{n}" }
    sequence(:author_names) { |n| [ "Author #{n}" ] }
  end
end
