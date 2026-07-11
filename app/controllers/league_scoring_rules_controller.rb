# frozen_string_literal: true

# Owner-only editor for a LeagueSeason's per-rule point overrides. Mirrors
# DraftsController's permission pattern. Edits are allowed at any time -
# Standings::Calculate resolves points through these overrides at read time,
# so the new values take effect on the next standings render with no recalc
# job to enqueue.
class LeagueScoringRulesController < ApplicationController
  include LeagueContext

  before_action :load_league
  before_action :load_league_season
  before_action :require_owner

  def edit
    render Views::LeagueScoringRules::Edit.new(
      league: @league,
      league_season: @league_season,
      overrides: ordered_overrides
    )
  end

  def update
    ApplicationRecord.transaction do
      overrides_params.each do |id, points|
        override = @league_season.scoring_rule_overrides.find(id)
        override.update!(points: points)
      end
    end
    redirect_to edit_league_scoring_rules_path(@league), notice: "Scoring updated."
  rescue ActiveRecord::RecordInvalid
    render Views::LeagueScoringRules::Edit.new(
      league: @league,
      league_season: @league_season,
      overrides: ordered_overrides
    ), status: :unprocessable_content
  end

  def reset
    LeagueSeasonScoringRules::Seed.call(@league_season, reset: true)
    redirect_to edit_league_scoring_rules_path(@league), notice: "Scoring reset to sport defaults."
  end

  private

  def ordered_overrides
    @league_season.scoring_rule_overrides.includes(:scoring_rule).ordered.to_a
  end

  # Form posts `overrides[<id>][points]=<value>`. Override IDs are dynamic
  # keys, so each value is permitted individually rather than declaring one
  # outer shape. Returns `{id_string => points_string}`.
  def overrides_params
    params.require(:overrides).each_pair.to_h do |id, attrs|
      [id, attrs.permit(:points)[:points]]
    end
  end
end
