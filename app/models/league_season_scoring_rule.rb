# frozen_string_literal: true

# Per-league_season override of a sport's ScoringRule point value. Owns only
# `points`; everything else (event_type, kind, round_key, labels, display_order,
# bye_backfill) is delegated to the underlying ScoringRule. Created by
# LeagueSeasonScoringRules::Seed on LeagueSeason creation and editable by
# league owners via the Scoring tab in league settings.
class LeagueSeasonScoringRule < ApplicationRecord
  belongs_to :league_season
  belongs_to :scoring_rule

  validates :points, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :scoring_rule_id, uniqueness: {scope: :league_season_id}

  delegate :event_type, :kind, :round_key, :label, :short_label,
    :display_order, :bye_backfill, :sport,
    to: :scoring_rule

  scope :ordered, -> { joins(:scoring_rule).order("scoring_rules.display_order", "scoring_rules.id") }
end
