# frozen_string_literal: true

class Views::Drafts::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(league:, league_season:)
    @league = league
    @league_season = league_season
  end

  def view_template
    render Views::Layouts::Application.new(title: "Draft settings - #{@league.name}") do
      main(class: "py-6") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Draft settings" }
            p(class: "text-sm text-base-content/70") { "Configure the draft for #{@league.name}." }

            render_errors

            if @league_season.draft_picks.any?
              div(class: "alert alert-info mt-3") do
                p { "Draft has started - these settings are locked." }
              end
              render_readonly_settings
            else
              render_form
            end

            render_participant_order_section

            div(class: "mt-4") do
              a(href: league_path(@league), class: "btn btn-ghost btn-sm inline-flex items-center gap-1") do
                render Views::Components::Icon.new(:chevron_left)
                plain "Back to league"
              end
            end
          end
        end
      end
    end
  end

  private

  def render_form
    form_with(model: @league_season, url: league_draft_path(@league), method: :patch,
      scope: :league_season, class: "space-y-4 mt-3") do |form|
      div(data: {controller: "draft-mode"}, class: "space-y-3") do
        fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
          legend(class: "fieldset-legend text-sm font-medium") { "Draft" }
          mode_radio("manual", "Manual - record both picks yourself")
          mode_radio("live", "Live - each player picks on the clock")

          div(class: "space-y-4 #{"hidden" unless @league_season.draft_mode == "live"}".strip,
            data_draft_mode_target: "liveOnly") do
            render_style_field
            render_datetime_field
            render_clock_field
          end
        end
      end
      div(class: "card-actions justify-end pt-2") do
        a(href: league_path(@league), class: "btn btn-ghost") { "Cancel" }
        form.submit "Save changes", class: "btn btn-primary"
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
        value: @league_season.pick_clock_seconds || LeagueSeason::DEFAULT_PICK_CLOCK_SECONDS,
        min: 10, step: 5, class: "input w-32")
    end
  end

  # Static dl-style summary of the locked-in settings. Mirrors the layout
  # of `render_form` without any inputs so owners can still see what was
  # configured for the in-progress / completed draft.
  def render_readonly_settings
    fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-2 mt-3") do
      legend(class: "fieldset-legend text-sm font-medium") { "Draft" }
      setting_row("Mode", @league_season.draft_mode.to_s.capitalize)
      if @league_season.draft_mode == "live"
        setting_row("Order", @league_season.draft_order_style.to_s.capitalize)
        if @league_season.draft_scheduled_at
          setting_row("Scheduled") do
            time(datetime: @league_season.draft_scheduled_at.iso8601,
              data: {controller: "local-time"}) do
              plain @league_season.draft_scheduled_at.strftime("%a %b %-d, %Y at %-l:%M %p %Z")
            end
          end
        end
        if @league_season.pick_clock_seconds
          setting_row("Pick clock", "#{@league_season.pick_clock_seconds}s")
        end
      end
    end
  end

  def setting_row(label, value = nil, &block)
    div(class: "flex items-baseline gap-3 text-sm") do
      span(class: "opacity-70 w-28 shrink-0") { label }
      if block
        span(class: "font-medium", &block)
      else
        span(class: "font-medium") { value }
      end
    end
  end

  def render_participant_order_section
    fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3 mt-4") do
      legend(class: "fieldset-legend text-sm font-medium") { "Draft order" }
      locked = @league_season.draft_picks.any?
      if locked
        p(class: "text-xs opacity-60") { "Locked - the draft is underway." }
      else
        p(class: "text-xs opacity-60") do
          plain "Reorder seats before the draft begins. Position #1 picks first."
        end
      end
      participants = @league_season.participants.to_a
      ul(class: "list bg-base-100 rounded-box border border-base-300") do
        participants.each_with_index do |p, idx|
          render_participant_row(p, first: idx.zero?, last: idx == participants.size - 1, locked: locked)
        end
      end
    end
  end

  def render_participant_row(participant, first:, last:, locked: false)
    li(class: "list-row flex items-center gap-3 px-3 py-2") do
      span(class: "badge badge-neutral") { "#" + participant.draft_position.to_s }
      span(class: "font-medium grow") do
        plain participant.display_name
        span(class: "badge badge-secondary badge-outline badge-sm ml-2") { "owner" } if participant.is_owner?
        span(class: "text-sm text-base-content/60 ml-2") { "(unclaimed)" } if participant.joined_at.nil?
      end
      next if locked
      div(class: "flex gap-1") do
        if first
          span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { render Views::Components::Icon.new(:chevron_up) }
        else
          button_to move_up_league_participant_path(@league, participant), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs",
            title: "Move up",
            aria: {label: "Move up"} do
            render Views::Components::Icon.new(:chevron_up)
          end
        end
        if last
          span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { render Views::Components::Icon.new(:chevron_down) }
        else
          button_to move_down_league_participant_path(@league, participant), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs",
            title: "Move down",
            aria: {label: "Move down"} do
            render Views::Components::Icon.new(:chevron_down)
          end
        end
      end
    end
  end

  def render_errors
    render Views::Components::ErrorAlert.new(records: @league_season, class_name: "mt-3")
  end
end
