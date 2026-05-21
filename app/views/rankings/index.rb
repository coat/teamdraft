# frozen_string_literal: true

class Views::Rankings::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Views::Components::TeamDirectoryHelpers

  def initialize(sport:, ranked:, unranked:, live_drafts_count: 0)
    @sport = sport
    @ranked = ranked
    @unranked = unranked
    @live_drafts_count = live_drafts_count
  end

  def view_template
    render Views::Layouts::Application.new(title: "#{@sport.name} rankings") do
      main(class: "py-6 space-y-4") do
        render_header
        render_live_banner if @live_drafts_count.positive?
        render_ranked_section
        render_unranked_section
      end
    end
  end

  private

  def render_header
    div(class: "flex items-center justify-between") do
      div do
        h1(class: "text-2xl font-semibold") { "#{@sport.name} rankings" }
        p(class: "text-sm text-base-content/70") do
          "Auto-picks for your seats use this order first, then the global default."
        end
      end
      a(href: rankings_path, class: "btn btn-ghost btn-sm") { "← All sports" }
    end
  end

  def render_live_banner
    div(class: "alert alert-info") do
      p { "Live draft in progress — edits apply to future auto-picks only." }
    end
  end

  def render_ranked_section
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title text-lg") { "Your ranking" }
        if @ranked.empty?
          p(class: "text-sm text-base-content/60") do
            "You haven't ranked any teams yet. Add some from the list below."
          end
        else
          render_ranked_table
        end
      end
    end
  end

  def render_ranked_table
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-10 bg-base-100") { "#" }
            th(class: "w-10 bg-base-100")
            th(class: "bg-base-100") { "Team" }
            th(class: "bg-base-100") { "Conf / Div" }
            th(class: "text-right bg-base-100")
          end
        end
        tbody do
          @ranked.each_with_index do |ranking, idx|
            render_ranked_row(ranking, first: idx.zero?, last: idx == @ranked.size - 1)
          end
        end
      end
    end
  end

  def render_ranked_row(ranking, first:, last:)
    team = ranking.team
    tr do
      th(class: "font-mono text-sm") { ranking.rank.to_s }
      th { render_team_swatch(team) }
      td do
        div(class: "flex flex-col") do
          span(class: "font-medium") { team.name }
          span(class: "text-xs opacity-60") { team.abbreviation }
        end
      end
      td(class: "text-sm whitespace-nowrap") { division_label(team) || "—" }
      th(class: "text-right") do
        div(class: "inline-flex gap-1") do
          if first
            span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { "▲" }
          else
            button_to "▲", move_up_sport_ranking_path(@sport.key, ranking),
              method: :patch, form: {class: "inline"},
              class: "btn btn-ghost btn-xs", title: "Move up"
          end
          if last
            span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { "▼" }
          else
            button_to "▼", move_down_sport_ranking_path(@sport.key, ranking),
              method: :patch, form: {class: "inline"},
              class: "btn btn-ghost btn-xs", title: "Move down"
          end
          button_to "Remove", sport_ranking_path(@sport.key, ranking),
            method: :delete, form: {class: "inline"},
            class: "btn btn-ghost btn-xs"
        end
      end
    end
  end

  def render_unranked_section
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title text-lg") { "Unranked" }
        p(class: "text-xs text-base-content/60") do
          "These follow the global default order in your auto-picks."
        end
        if @unranked.any?
          render_unranked_table
        else
          p(class: "text-sm text-base-content/60") { "Every team is ranked." }
        end
      end
    end
  end

  def render_unranked_table
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-10 bg-base-100")
            th(class: "bg-base-100") { "Team" }
            th(class: "bg-base-100") { "Conf / Div" }
            th(class: "bg-base-100") { "Global rank" }
            th(class: "text-right bg-base-100")
          end
        end
        tbody do
          @unranked.each { |team| render_unranked_row(team) }
        end
      end
    end
  end

  def render_unranked_row(team)
    tr do
      th { render_team_swatch(team) }
      td do
        div(class: "flex flex-col") do
          span(class: "font-medium") { team.name }
          span(class: "text-xs opacity-60") { team.abbreviation }
        end
      end
      td(class: "text-sm whitespace-nowrap") { division_label(team) || "—" }
      td(class: "font-mono text-sm") { team.default_pick_rank ? "##{team.default_pick_rank}" : "—" }
      th(class: "text-right") do
        button_to "Add", sport_rankings_create_path(@sport.key, team_id: team.id),
          method: :post, form: {class: "inline"},
          class: "btn btn-ghost btn-xs"
      end
    end
  end
end
