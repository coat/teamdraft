FactoryBot.define do
  factory :sport do
    sequence(:key) { |n| "sport-#{n}" }
    name { "Sport" }
    active { true }
    scoring_rules do
      {
        "regular_win" => 1,
        "playoff_appearance" => 5,
        "divisional_appearance" => 5,
        "conference_appearance" => 10,
        "championship_appearance" => 10,
        "championship_win" => 5
      }
    end

    trait :nfl do
      key { "nfl" }
      name { "NFL" }
    end
  end
end
