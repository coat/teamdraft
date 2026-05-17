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
              render_draft_section
              div(class: "card-actions justify-end pt-2") do
                a(href: league_path(@league), class: "btn btn-ghost") { "Cancel" }
                form.submit "Save changes", class: "btn btn-primary"
              end
            end
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
        span(class: "label-text") { "Private — hide this league from public season listings" }
      end
    end
  end

  def render_draft_section
    return unless @league_season

    if @league_season.draft_picks.any?
      div(class: "alert alert-info") do
        p { "Draft has started — these settings are locked." }
      end
      return
    end

    div(data: {controller: "draft-mode"}, class: "space-y-3") do
      fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
        legend(class: "fieldset-legend text-sm font-medium") { "Draft" }
        mode_radio("manual", "Manual — record both picks yourself")
        mode_radio("live", "Live — each player picks on the clock")

        div(class: "space-y-4 #{"hidden" unless @league_season.draft_mode == "live"}".strip,
          data_draft_mode_target: "liveOnly") do
          render_style_field
          render_datetime_field
          render_clock_field
        end
      end
    end
  end

  def mode_radio(value, copy)
    div(class: "space-y-1") do
      label(class: "label cursor-pointer justify-start gap-3") do
        input(type: "radio", name: "league_season[draft_mode]", value: value,
          checked: @league_season.draft_mode == value,
          class: "radio radio-primary",
          data: {action: "change->draft-mode#sync"})
        span(class: "label-text") { copy }
      end
    end
  end

  def render_style_field
    div(class: "space-y-1") do
      label(for: "league_season_draft_order_style", class: "label label-text font-medium") { "Draft order" }
      select(name: "league_season[draft_order_style]",
        id: "league_season_draft_order_style",
        class: "select w-full") do
        LeagueSeason::DRAFT_ORDER_STYLES.each do |style|
          option(value: style, selected: style == @league_season.draft_order_style) { style.capitalize }
        end
      end
    end
  end

  def render_datetime_field
    div(class: "space-y-1", data: {controller: "local-datetime-field"}) do
      label(for: "league_season_draft_scheduled_at", class: "label label-text font-medium") { "Draft date" }
      input(type: "datetime-local",
        name: "league_season[draft_scheduled_at]",
        id: "league_season_draft_scheduled_at",
        value: @league_season.draft_scheduled_at&.strftime("%Y-%m-%dT%H:%M"),
        step: 60,
        class: "input w-full",
        data: {local_datetime_field_target: "input", action: "change->local-datetime-field#update"})
      input(type: "hidden", name: "league_season[time_zone]",
        data: {local_datetime_field_target: "timezone"})
      span(class: "label-text-alt text-xs opacity-60",
        data: {local_datetime_field_target: "hint"}) { "Detecting your timezone…" }
    end
  end

  def render_clock_field
    div(class: "space-y-1") do
      label(for: "league_season_pick_clock_seconds", class: "label label-text font-medium") { "Pick clock (seconds)" }
      input(type: "number",
        name: "league_season[pick_clock_seconds]",
        id: "league_season_pick_clock_seconds",
        value: @league_season.pick_clock_seconds || 60,
        min: 10, step: 5, class: "input w-32")
    end
  end

  def render_errors
    return unless @league.errors.any? || @league_season&.errors&.any?
    div(class: "alert alert-error mt-3", role: "alert") do
      ul(class: "list-disc list-inside") do
        @league.errors.full_messages.each { |msg| li { msg } }
        @league_season&.errors&.full_messages&.each { |msg| li { msg } }
      end
    end
  end

  def history_hint
    history = @league.slugs.where.not(slug: @league.slug).limit(2).pluck(:slug)
    return "" if history.empty?
    " (e.g. " + history.map { |s| "/leagues/#{s}" }.join(", ") + ")"
  end
end
