FactoryBot.define do
  factory :author do
    sequence(:name) { |n| "Writer #{n}" }
  end
end
