FactoryBot.define do
  factory :league do
    sequence(:name) { |n| "League #{n}" }
    sequence(:slug) { |n| "league-#{n}" }
  end
end
