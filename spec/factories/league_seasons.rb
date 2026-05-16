FactoryBot.define do
  factory :league_season do
    league
    season
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
      after(:create) do |ls|
        create(:participant, :owner, league_season: ls, display_name: "Alice", draft_position: 1)
        create(:participant, league_season: ls, display_name: "Bob", draft_position: 2)
      end
    end
  end
end
