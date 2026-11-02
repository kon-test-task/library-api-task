FactoryBot.define do
  factory :borrowing do
    book
    reader

    trait :returned do
      borrowed_at { 10.days.ago }
      returned_at { 5.days.ago }
    end
  end
end
