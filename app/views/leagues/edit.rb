# frozen_string_literal: true

class Views::Leagues::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(league:, league_season:)
    @league = league
    @league_season = league_season
  end

  def view_template
    render Views::Layouts::Application.new(title: "Edit league") do
      main(class: "py-6") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Edit league" }
            p(class: "text-sm text-base-content/70") do
              plain "The URL updates when you rename. Old links keep redirecting#{history_hint}."
            end

            render_errors

            form_with(model: @league, url: league_path(@league), method: :patch, class: "space-y-4 mt-3") do |form|
              render_identity_section(form)
              div(class: "card-actions justify-end pt-2") do
                a(href: league_path(@league), class: "btn btn-ghost") { "Cancel" }
                form.submit "Save changes", class: "btn btn-primary"
              end
            end
            render_draft_settings_link
            render_scoring_link
          end
        end
      end
    end
  end

  private

  def render_identity_section(form)
    fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
      legend(class: "fieldset-legend text-sm font-medium") { "League" }
      div(class: "space-y-1") do
        form.label :name, "Name", class: "label label-text font-medium"
        form.text_field :name, value: @league.name, required: true, class: "input w-full"
      end
      label(class: "label cursor-pointer justify-start gap-3") do
        form.check_box :private, class: "checkbox checkbox-primary"
        span(class: "label-text") { "Private - hide this league from public season listings" }
      end
    end
  end

  def render_draft_settings_link
    return unless @league_season
    div(class: "mt-4") do
      a(href: edit_league_draft_path(@league),
        class: "btn btn-ghost w-full justify-between") do
        span(class: "inline-flex items-center gap-1") do
          plain "Draft settings"
          render Views::Components::Icon.new(:chevron_right)
        end
        span(class: "text-xs opacity-70") { draft_settings_summary }
      end
    end
  end

  def render_scoring_link
    return unless @league_season
    div(class: "mt-2") do
      a(href: edit_league_scoring_rules_path(@league),
        class: "btn btn-ghost w-full justify-between") do
        span(class: "inline-flex items-center gap-1") do
          plain "Scoring"
          render Views::Components::Icon.new(:chevron_right)
        end
        span(class: "text-xs opacity-70") { scoring_summary }
      end
    end
  end

  def scoring_summary
    overrides = @league_season.scoring_rule_overrides.includes(:scoring_rule)
    customized = overrides.count { |o| o.points != o.scoring_rule.points }
    return "Sport defaults" if customized.zero?
    "#{customized} customized"
  end

  def draft_settings_summary
    parts = [@league_season.draft_mode.capitalize]
    if @league_season.draft_mode == "live" && @league_season.pick_clock_seconds
      parts << "#{@league_season.pick_clock_seconds}s clock"
    end
    parts.join(" · ")
  end

  def render_errors
    render Views::Components::ErrorAlert.new(
      records: [@league, @league_season],
      class_name: "mt-3"
    )
  end

  def history_hint
    history = @league.slugs.where.not(slug: @league.slug).limit(2).pluck(:slug)
    return "" if history.empty?
    " (e.g. " + history.map { |s| "/leagues/#{s}" }.join(", ") + ")"
  end
end
