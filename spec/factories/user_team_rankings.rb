FactoryBot.define do
  factory :user_team_ranking do
    user
    team
    sequence(:rank) { |n| n }
  end
end
