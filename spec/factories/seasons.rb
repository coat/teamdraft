FactoryBot.define do
  factory :season do
    sport
    sequence(:year) { |n| 2000 + n }
    label { "#{year} Season" }
    starts_on { Date.new(year, 9, 1) }
    ends_on { Date.new(year + 1, 2, 28) }
    status { "active" }
  end
end
