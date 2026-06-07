# frozen_string_literal: true

class Views::Admin::Games::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(game:)
    @game = game
  end

  def view_template
    matchup = "#{@game.away_season_team.team.name} @ #{@game.home_season_team.team.name}"
    render Views::Layouts::Admin.new(
      title: "Edit game",
      section: :games,
      breadcrumbs: [
        ["Games", admin_games_path(season_id: @game.season_id)],
        [matchup, nil],
        ["Edit", nil]
      ]
    ) do
      render Views::Components::Admin::PageHeader.new(
        title: matchup,
        subtitle: "Manual override. Saving with status=final triggers a scoring recompute."
      )
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body") do
          render Views::Components::ErrorAlert.new(records: @game)

          rounds = [Game::REGULAR_SEASON] +
            @game.season.sport.scoring_rules.where(kind: "playoff_appearance").ordered.pluck(:round_key)
          form_with(model: @game, url: admin_game_path(@game), method: :patch, class: "space-y-3") do |f|
            select_row(f, :status, "Status", Game::STATUSES)
            select_row(f, :round, "Round", rounds)
            number_row(f, :week, "Week", min: 1)
            datetime_row(f, :starts_at, "Start time", value: @game.starts_at&.iso8601)
            number_row(f, :home_score, "Home score", min: 0)
            number_row(f, :away_score, "Away score", min: 0)
            div(class: "card-actions justify-end pt-2") do
              a(href: admin_games_path(season_id: @game.season_id), class: "btn btn-ghost") { "Cancel" }
              f.submit "Save", class: "btn btn-primary"
            end
          end
        end
      end
    end
  end

  private

  def select_row(f, name, label, options)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.select name, options.map { |o| [o, o] }, {}, class: "select w-full"
    end
  end

  def number_row(f, name, label, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.number_field name, class: "input w-full", **opts
    end
  end

  def datetime_row(f, name, label, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.datetime_local_field name, class: "input w-full", **opts
    end
  end
end
