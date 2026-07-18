# frozen_string_literal: true

class Views::Rankings::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TurboFrameTag
  include Views::Components::TeamDirectoryHelpers

  def initialize(sport:, ranked:, unranked:, frame: false)
    @sport = sport
    @ranked = ranked
    @unranked = unranked
    @frame = frame
  end

  def view_template
    if @frame
      turbo_frame_tag "user_rankings", class: "space-y-4 block" do
        render_ranked_section
        render_unranked_section
      end
    else
      render Views::Layouts::Application.new(title: "#{@sport.name} rankings") do
        main(class: "py-6 space-y-4") do
          render_header
          render_ranked_section
          render_unranked_section
        end
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
      a(href: rankings_path, class: "btn btn-ghost btn-sm inline-flex items-center gap-1") do
        render Views::Components::Icon.new(:chevron_left)
        plain "All sports"
      end
    end
  end

  def render_ranked_section
    section_panel do
      h2(class: "card-title text-lg") { "Your ranking" }
      if @ranked.empty?
        p(class: "text-sm text-base-content/70") do
          "You haven't ranked any teams yet. Add some from the list below."
        end
      else
        render_ranked_table
      end
    end
  end

  # In frame mode (embedded as a tab inside the draft view) the rankings
  # are already inside a tab-content panel, so wrapping each section in
  # another card just stacks padding and steals horizontal width. Render
  # flat instead.
  def section_panel(&block)
    if @frame
      div(class: "space-y-2", &block)
    else
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body", &block)
      end
    end
  end

  def render_ranked_table
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-10 bg-base-100", scope: "col") { "#" }
            th(class: "w-10 bg-base-100", scope: "col") { span(class: "sr-only") { "Logo" } }
            th(class: "bg-base-100", scope: "col") { "Team" }
            th(class: "bg-base-100 hidden sm:table-cell", scope: "col") { "Conf / Div" }
            th(class: "text-right bg-base-100", scope: "col") { span(class: "sr-only") { "Actions" } }
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
      # sticky + bg mirror daisyUI's .table-pin-cols th pinning; td keeps
      # non-header cells from being misread as row headers.
      th(class: "font-mono text-sm", scope: "row") { ranking.rank.to_s }
      td(class: "sticky left-0 bg-base-100") { render_team_swatch(team) }
      td(class: "font-medium") { team.name }
      td(class: "text-sm whitespace-nowrap hidden sm:table-cell") { division_label(team) || "-" }
      td(class: "sticky right-0 bg-base-100 text-right") do
        div(class: "inline-flex gap-1") do
          if first
            span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { render Views::Components::Icon.new(:chevron_up) }
          else
            button_to move_up_sport_ranking_path(@sport.key, ranking),
              method: :patch, form: {class: "inline"},
              class: "btn btn-ghost btn-xs", title: "Move up",
              aria: {label: "Move up"} do
              render Views::Components::Icon.new(:chevron_up)
            end
          end
          if last
            span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { render Views::Components::Icon.new(:chevron_down) }
          else
            button_to move_down_sport_ranking_path(@sport.key, ranking),
              method: :patch, form: {class: "inline"},
              class: "btn btn-ghost btn-xs", title: "Move down",
              aria: {label: "Move down"} do
              render Views::Components::Icon.new(:chevron_down)
            end
          end
          button_to sport_ranking_path(@sport.key, ranking),
            method: :delete, form: {class: "inline"},
            class: "btn btn-ghost btn-xs", title: "Remove",
            aria: {label: "Remove"} do
            render Views::Components::Icon.new(:trash)
          end
        end
      end
    end
  end

  def render_unranked_section
    section_panel do
      h2(class: "card-title text-lg") { "Unranked" }
      p(class: "text-xs text-base-content/70") do
        "These follow the global default order in your auto-picks."
      end
      if @unranked.any?
        render_unranked_table
      else
        p(class: "text-sm text-base-content/70") { "Every team is ranked." }
      end
    end
  end

  def render_unranked_table
    div(class: "overflow-x-auto") do
      table(class: "table table-sm table-zebra table-pin-cols") do
        thead do
          tr do
            th(class: "w-10 bg-base-100", scope: "col") { span(class: "sr-only") { "Logo" } }
            th(class: "bg-base-100", scope: "col") { "Team" }
            th(class: "bg-base-100 hidden sm:table-cell", scope: "col") { "Conf / Div" }
            th(class: "bg-base-100", scope: "col") { "Global rank" }
            th(class: "text-right bg-base-100", scope: "col") { span(class: "sr-only") { "Actions" } }
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
      td(class: "sticky left-0 bg-base-100") { render_team_swatch(team) }
      td(class: "font-medium") { team.name }
      td(class: "text-sm whitespace-nowrap hidden sm:table-cell") { division_label(team) || "-" }
      td(class: "font-mono text-sm") { team.default_pick_rank ? "##{team.default_pick_rank}" : "-" }
      td(class: "sticky right-0 bg-base-100 text-right") do
        button_to sport_rankings_create_path(@sport.key, team_id: team.id),
          method: :post, form: {class: "inline"},
          class: "btn btn-ghost btn-xs", title: "Add",
          aria: {label: "Add"} do
          render Views::Components::Icon.new(:plus)
        end
      end
    end
  end
end
