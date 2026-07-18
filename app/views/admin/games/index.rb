# frozen_string_literal: true

class Views::Admin::Games::Index < Views::Base
  LABEL_CLASSES = "label label-text text-xs uppercase tracking-wide"

  def initialize(query:, games:, all_seasons:, team_options:, round_options:, pagy:)
    @query = query
    @games = games
    @all_seasons = all_seasons
    @team_options = team_options
    @round_options = round_options
    @pagy = pagy
  end

  def view_template
    render Views::Layouts::Admin.new(title: "Games", section: :games, breadcrumbs: [["Games", nil]]) do
      render Views::Components::Admin::PageHeader.new(title: "Games")
      render_filter_card
      render_games_table
      render Views::Components::Admin::Pagination.new(pagy: @pagy)
    end
  end

  private

  def render_filter_card
    render Views::Components::Admin::FilterCard.new(
      url: admin_games_path, query: @query,
      clear_path: admin_games_path(season_id: @query.season_id)
    ) do |form|
      div(class: "space-y-1") do
        form.label :season_id, "Season", class: LABEL_CLASSES
        form.select :season_id,
          @all_seasons.map { |s| ["#{s.label} (#{s.status})", s.id] },
          {selected: @query.season_id},
          class: "select select-bordered",
          data: {controller: "auto-submit", action: "change->auto-submit#submit"}
      end
      div(class: "space-y-1") do
        form.label :status, "Status", class: LABEL_CLASSES
        form.select :status,
          [["Any status", ""]] + Game::STATUSES.map { |s| [s.humanize, s] },
          {selected: @query.status},
          class: "select select-bordered"
      end
      div(class: "space-y-1") do
        form.label :round, "Round", class: LABEL_CLASSES
        form.select :round,
          [["Any round", ""]] + @round_options.map { |r| [r.humanize, r] },
          {selected: @query.round},
          class: "select select-bordered"
      end
      div(class: "space-y-1") do
        form.label :week, "Week", class: LABEL_CLASSES
        # The narrow input otherwise shares a line with its inline-flex label.
        div { form.number_field :week, value: @query.week, min: 0, class: "input input-bordered w-20" }
      end
      div(class: "space-y-1") do
        form.label :team_id, "Team", class: LABEL_CLASSES
        form.select :team_id,
          [["Any team", ""]] + @team_options,
          {selected: @query.team_id},
          class: "select select-bordered"
      end
      div(class: "space-y-1") do
        form.label :from, "From", class: LABEL_CLASSES
        form.date_field :from, value: @query.from, class: "input input-bordered"
      end
      div(class: "space-y-1") do
        form.label :to, "To", class: LABEL_CLASSES
        form.date_field :to, value: @query.to, class: "input input-bordered"
      end
    end
  end

  def render_games_table
    render Views::Components::Admin::TableCard.new do
      thead do
        tr do
          render Views::Components::SortableHeader.new(query: @query, column: "starts_at", label: "When", path: admin_games_path)
          render Views::Components::SortableHeader.new(query: @query, column: "round", label: "Round", path: admin_games_path)
          render Views::Components::SortableHeader.new(query: @query, column: "week", label: "Wk", path: admin_games_path)
          th(scope: "col") { "Matchup" }
          th(scope: "col") { "Score" }
          render Views::Components::SortableHeader.new(query: @query, column: "status", label: "Status", path: admin_games_path)
          th(scope: "col") { span(class: "sr-only") { "Actions" } }
        end
      end
      tbody do
        if @games.empty?
          tr do
            td(colspan: "7") do
              div(class: "alert alert-info my-2") { span { empty_message } }
            end
          end
        else
          @games.each { |g| render_row(g) }
        end
      end
    end
  end

  def empty_message
    if @query.season.nil? || @query.season.games.none?
      "No games for this season yet. Use the dashboard's sync action to pull them."
    else
      "No games match these filters."
    end
  end

  def render_row(game)
    tr do
      td(class: "whitespace-nowrap") { game.starts_at&.strftime("%a %b %-d %-l:%M%P") }
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
    return "-" unless game.home_score && game.away_score
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
