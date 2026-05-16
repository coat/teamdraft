FactoryBot.define do
  factory :participant do
    league_season
    sequence(:display_name) { |n| "Player #{n}" }
    draft_position { 1 }
    is_owner { false }
    joined_at { Time.current }

    trait :owner do
      is_owner { true }
      draft_position { 1 }
    end

    trait :unjoined do
      joined_at { nil }
      invited_at { Time.current }
    end
  end
end
