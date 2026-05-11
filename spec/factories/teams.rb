FactoryBot.define do
  factory :team do
    sport
    sequence(:name) { |n| "Team #{n}" }
    sequence(:slug) { |n| "team-#{n}" }
    sequence(:abbreviation) { |n| "T#{n}" }
    default_pick_rank { nil }
  end
end
