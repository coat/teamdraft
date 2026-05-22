# frozen_string_literal: true

# Owner-only editor for a LeagueSeason's per-rule point overrides. Mirrors
# DraftsController's permission pattern. Edits are allowed at any time -
# Standings::Calculate resolves points through these overrides at read time,
# so the new values take effect on the next standings render with no recalc
# job to enqueue.
class LeagueScoringRulesController < ApplicationController
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
      overrides_params.each do |id, attrs|
        override = @league_season.scoring_rule_overrides.find(id)
        override.update!(points: attrs[:points])
      end
    end
    redirect_to edit_league_scoring_rules_path(@league), notice: "Scoring updated."
  rescue ActiveRecord::RecordInvalid
    render Views::LeagueScoringRules::Edit.new(
      league: @league,
      league_season: @league_season,
      overrides: ordered_overrides
    ), status: :unprocessable_entity
  end

  def reset
    LeagueSeasonScoringRules::Seed.call(@league_season, reset: true)
    redirect_to edit_league_scoring_rules_path(@league), notice: "Scoring reset to sport defaults."
  end

  private

  def load_league
    @league = League.friendly.find(params[:league_id])
  end

  def load_league_season
    @league_season = @league.current_league_season
    unless @league_season
      redirect_to league_path(@league), alert: "No active season for this league."
    end
  end

  def require_owner
    participant = current_participant_for(@league)
    unless participant&.is_owner?
      redirect_to league_path(@league),
        alert: "Only the league owner can edit this league."
    end
  end

  def ordered_overrides
    @league_season.scoring_rule_overrides.includes(:scoring_rule).ordered.to_a
  end

  def overrides_params
    params.require(:overrides).to_unsafe_h.transform_values { |v| v.slice(:points) }
  end
end
