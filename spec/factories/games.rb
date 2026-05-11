FactoryBot.define do
  factory :game do
    season
    home_season_team { association(:season_team, season: season) }
    away_season_team { association(:season_team, season: season) }
    round { "regular_season" }
    week { 1 }
    status { "scheduled" }
    kickoff_at { 1.day.from_now }

    trait :final do
      status { "final" }
      home_score { 24 }
      away_score { 17 }
      completed_at { Time.current }
    end
  end
end
