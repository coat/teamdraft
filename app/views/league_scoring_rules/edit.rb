# frozen_string_literal: true

class Views::LeagueScoringRules::Edit < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(league:, league_season:, overrides:)
    @league = league
    @league_season = league_season
    @overrides = overrides
  end

  def view_template
    render Views::Layouts::Application.new(title: "Scoring - #{@league.name}") do
      main(class: "py-6") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Scoring" }
            p(class: "text-sm text-base-content/70") do
              plain "Customize point values for this league. "
              plain "Standings update immediately - no recalculation needed."
            end

            render_errors
            render_form
            render_reset
            render_back
          end
        end
      end
    end
  end

  private

  def render_form
    form_with(url: league_scoring_rules_path(@league), method: :patch,
      class: "space-y-6 mt-3") do |_form|
      grouped = @overrides.group_by { |o| o.kind }
      render_group("Regular season", grouped["regular_win"] || [])
      render_group("Playoff appearances", grouped["playoff_appearance"] || [])
      render_group("Championship", grouped["championship_win"] || [])

      div(class: "card-actions justify-end pt-2") do
        a(href: edit_league_path(@league), class: "btn btn-ghost") { "Cancel" }
        button(type: "submit", class: "btn btn-primary") { "Save changes" }
      end
    end
  end

  def render_group(title, overrides)
    return if overrides.empty?
    fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
      legend(class: "fieldset-legend text-sm font-medium") { title }
      overrides.each { |o| render_row(o) }
    end
  end

  def render_row(override)
    div(class: "flex items-center gap-3") do
      div(class: "grow") do
        div(class: "font-medium") { override.label }
        div(class: "text-xs opacity-60") { default_hint(override) }
      end
      div(class: "shrink-0") do
        label(class: "label-text-alt sr-only", for: input_id(override)) { override.label }
        input(type: "number",
          name: "overrides[#{override.id}][points]",
          id: input_id(override),
          value: override.points,
          min: 0,
          step: 1,
          class: "input input-bordered w-24 text-right")
        span(class: "ml-2 text-sm opacity-70") { "pts" }
      end
    end
  end

  def render_reset
    div(class: "mt-6 pt-4 border-t border-base-300") do
      p(class: "text-xs opacity-60 mb-2") do
        plain "Restore all point values to the sport's defaults."
      end
      button_to "Reset to sport defaults",
        reset_league_scoring_rules_path(@league),
        method: :post,
        form: {data: {turbo_confirm: "Reset all scoring values to sport defaults?"}},
        class: "btn btn-ghost btn-sm"
    end
  end

  def render_back
    div(class: "mt-4") do
      a(href: edit_league_path(@league), class: "btn btn-ghost btn-sm inline-flex items-center gap-1") do
        render Views::Components::Icon.new(:chevron_left)
        plain "Back to league settings"
      end
    end
  end

  def render_errors
    invalid = @overrides.select { |o| o.errors.any? }
    return if invalid.empty?
    div(class: "alert alert-error mt-3", role: "alert") do
      ul(class: "list-disc list-inside") do
        invalid.each do |o|
          o.errors.full_messages.each { |msg| li { "#{o.label}: #{msg}" } }
        end
      end
    end
  end

  def input_id(override)
    "overrides_#{override.id}_points"
  end

  def default_hint(override)
    default = override.scoring_rule.points
    return "Default: #{default} pt#{"s" unless default == 1}" if override.points == default
    "Customized · Sport default: #{default}"
  end
end
