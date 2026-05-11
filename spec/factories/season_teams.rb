FactoryBot.define do
  factory :season_team do
    season
    team { association(:team, sport: season.sport) }
  end
end
