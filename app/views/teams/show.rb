# frozen_string_literal: true

class Views::Teams::Show < Views::Base
  def initialize(season:, season_team:, games:)
    @season = season
    @season_team = season_team
    @team = season_team.team
    @games = games
  end

  def round_labels
    @round_labels ||= @season.sport.scoring_rules
      .where.not(round_key: nil)
      .pluck(:round_key, :short_label).to_h
  end

  def view_template
    render Views::Layouts::Application.new(title: "#{@team.name} · #{@season.label}") do
      main(class: "py-6 space-y-4") do
        render Views::Components::Breadcrumbs.new(trail: [
          ["Seasons", seasons_path],
          [@season.label, season_path(@season)],
          [@team.name, nil]
        ])

        div do
          h1(class: "text-3xl font-bold") { @team.name }
          p(class: "text-sm opacity-70") do
            plain [@team.conference, @team.division].compact.join(" ")
            plain " · #{@season.label}"
          end
        end

        render_games_table
      end
    end
  end

  private

  def render_games_table
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Schedule" }
        if @games.empty?
          p(class: "text-base-content/60") { "No games scheduled yet." }
        else
          div(class: "overflow-x-auto") do
            table(class: "table table-sm table-zebra") do
              thead do
                tr do
                  th { "Week" }
                  th { "When" }
                  th { "Opponent" }
                  th { "Result" }
                  th { "Status" }
                end
              end
              tbody do
                @games.each { |g| render_row(g) }
              end
            end
          end
        end
      end
    end
  end

  def render_row(game)
    tr do
      td { week_label(game) }
      td(class: "text-sm whitespace-nowrap") { game.kickoff_at&.strftime("%a %b %-d %-l:%M%P") || "—" }
      td { opponent_label(game) }
      td(class: "font-mono") { result_cell(game) }
      td { span(class: "badge badge-sm #{status_color(game.status)}") { game.status } }
    end
  end

  def week_label(game)
    return game.week.to_s if game.round == "regular_season" && game.week
    round_labels[game.round] || game.round.to_s.humanize
  end

  def opponent_label(game)
    if game.home_season_team_id == @season_team.id
      "vs #{game.away_season_team&.team&.abbreviation || "?"}"
    else
      "@ #{game.home_season_team&.team&.abbreviation || "?"}"
    end
  end

  def result_cell(game)
    return plain("—") unless game.status == "final" && game.home_score && game.away_score
    home = game.home_season_team_id == @season_team.id
    our_score = home ? game.home_score : game.away_score
    their_score = home ? game.away_score : game.home_score
    outcome = if our_score > their_score
      ["W", "badge-success"]
    elsif our_score < their_score
      ["L", "badge-error"]
    else
      ["T", "badge-ghost"]
    end
    span(class: "badge badge-sm #{outcome[1]} mr-1") { outcome[0] }
    plain "#{our_score}–#{their_score}"
  end

  def status_color(status)
    case status
    when "final" then "badge-success"
    when "in_progress" then "badge-warning"
    when "postponed" then "badge-error"
    else "badge-ghost"
    end
  end
end
