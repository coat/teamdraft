# frozen_string_literal: true

class Views::Admin::Games::Index < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(season:, games:, all_seasons:, pagy:)
    @season = season
    @games = games
    @all_seasons = all_seasons
    @pagy = pagy
  end

  def view_template
    render Views::Layouts::Admin.new(title: "Games", section: :games, breadcrumbs: [["Games", nil]]) do
      render Views::Components::Admin::PageHeader.new(title: "Games")
      render_season_picker
      if @games.any?
        render_games_table
        render Views::Components::Admin::Pagination.new(pagy: @pagy)
      else
        p(class: "text-base-content/60") { "No games for this season yet. Use the dashboard's sync action to pull them." }
      end
    end
  end

  private

  def render_season_picker
    form_with(url: admin_games_path, method: :get, local: true, class: "space-y-1 max-w-sm") do |f|
      f.label :season_id, "Season", class: "label label-text font-medium"
      f.select :season_id,
        @all_seasons.map { |s| ["#{s.label} (#{s.status})", s.id] },
        {include_blank: false},
        onchange: "this.form.requestSubmit()", class: "select w-full"
      noscript { f.submit "Go", class: "btn btn-sm mt-2" }
    end
  end

  def render_games_table
    render Views::Components::Admin::TableCard.new do
      thead do
        tr do
          th { "When" }
          th { "Round" }
          th { "Wk" }
          th { "Matchup" }
          th { "Score" }
          th { "Status" }
          th
        end
      end
      tbody do
        @games.each { |g| render_row(g) }
      end
    end
  end

  def render_row(game)
    tr do
      td(class: "whitespace-nowrap") { game.kickoff_at&.strftime("%a %b %-d %-l:%M%P") }
      td { game.round }
      td { game.week&.to_s }
      td { "#{game.away_season_team.team.abbreviation} @ #{game.home_season_team.team.abbreviation}" }
      td(class: "font-mono") { score_display(game) }
      td { span(class: status_badge(game.status)) { game.status } }
      td do
        a(href: edit_admin_game_path(game), class: "btn btn-ghost btn-xs",
          title: "Edit", aria_label: "Edit") do
          render Views::Components::Icon.new(:pencil_square)
        end
      end
    end
  end

  def score_display(game)
    return "—" unless game.home_score && game.away_score
    "#{game.away_score}–#{game.home_score}"
  end

  def status_badge(status)
    base = "badge badge-sm"
    case status
    when "final" then "#{base} badge-success"
    when "in_progress" then "#{base} badge-warning"
    when "postponed" then "#{base} badge-error"
    else "#{base} badge-ghost"
    end
  end
end
