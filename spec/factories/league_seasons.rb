FactoryBot.define do
  factory :league_season do
    league
    season
    sequence(:invite_code) { |n| "test-code-#{n}-#{SecureRandom.hex(2)}" }
    size { 2 }
    draft_mode { "live" }
    draft_order_style { "linear" }
    pick_clock_seconds { 30 }
    status { "draft_pending" }
    current_pick_number { 1 }

    transient do
      with_scoring_rule_overrides { true }
    end

    after(:create) do |ls, evaluator|
      next unless evaluator.with_scoring_rule_overrides
      next if ls.scoring_rule_overrides.any?
      LeagueSeasonScoringRules::Seed.call(ls)
    end

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
