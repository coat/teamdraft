FactoryBot.define do
  factory :league do
    season
    sequence(:name) { |n| "League #{n}" }
    sequence(:slug) { |n| "league-#{n}" }
    size { 2 }
    draft_mode { "live" }
    draft_order_style { "linear" }
    pick_clock_seconds { 30 }
    status { "draft_pending" }
    current_pick_number { 1 }

    trait :manual do
      draft_mode { "manual" }
      pick_clock_seconds { nil }
    end

    trait :with_two_participants do
      after(:create) do |league|
        create(:participant, :owner, league: league, display_name: "Alice", draft_position: 1)
        create(:participant, league: league, display_name: "Bob", draft_position: 2)
      end
    end
  end
end
