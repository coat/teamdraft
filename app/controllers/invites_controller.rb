# frozen_string_literal: true

class InvitesController < ApplicationController
  def show
    code = params[:code].to_s.strip
    league_season = LeagueSeason.where("LOWER(invite_code) = ?", code.downcase).first
    if league_season
      redirect_to league_path(league_season.league, invite: league_season.invite_code)
    else
      redirect_to root_path, alert: "That invite link is no longer valid."
    end
  end
end
