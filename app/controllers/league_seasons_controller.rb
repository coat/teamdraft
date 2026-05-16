# frozen_string_literal: true

class LeagueSeasonsController < ApplicationController
  def show
    @league = League.friendly.find(params[:league_id])
    @league_season = @league.league_seasons
      .joins(:season).find_by!(seasons: {year: params[:year].to_i})

    render Views::Leagues::Show.new(
      league: @league,
      league_season: @league_season,
      current_participant: current_participant_for(@league)
    )
  end
end
