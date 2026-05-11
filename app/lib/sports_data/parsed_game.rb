# frozen_string_literal: true

module SportsData
  # Provider-agnostic representation of a single game pulled from an external
  # source. `home_team_external_id` / `away_team_external_id` are matched
  # against `teams.external_id` to resolve them to local SeasonTeams.
  ParsedGame = Data.define(
    :external_id,
    :home_team_external_id,
    :away_team_external_id,
    :home_score,
    :away_score,
    :kickoff_at,
    :round,
    :week,
    :status
  )
end
