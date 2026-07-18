# frozen_string_literal: true

# The "create a league" form, used on the landing page and at /leagues/new.
# Posts to LeaguesController#create. The scheduled date is only meaningful
# for live drafts; the draft-mode Stimulus controller hides it when
# "manual" is selected.
class Views::Leagues::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(league:, seasons:, errors: [], submit_label: "Create league")
    @league = league
    @seasons = seasons
    @errors = errors
    @submit_label = submit_label
  end

  def view_template
    render_errors if @errors.any?

    form_with(model: @league, url: leagues_path, method: :post, scope: :league,
      class: "space-y-4", data: {controller: "draft-mode"}) do |form|
      render_season_field(form)
      render_text_field(form, :your_name, "Your name", autocomplete: "given-name")
      render_text_field(form, :opponent_name, "Opponent's name")
      render_mode_fieldset(form)

      div(class: "card-actions justify-end pt-1") do
        form.submit @submit_label, class: "btn btn-primary"
      end
    end
  end

  private

  def render_season_field(form)
    return if @seasons.blank?
    active = @seasons.select { |s| s.status == "active" }
    upcoming = @seasons.select { |s| s.status == "upcoming" }
    grouped = [
      ["Upcoming", upcoming.map { |s| [s.label, s.id] }],
      ["In Progress", active.map { |s| [s.label, s.id] }]
    ]

    div(class: "space-y-1") do
      form.label :season_id, "Season", class: "label label-text font-medium"
      form.select :season_id,
        grouped,
        {include_blank: false, selected: @league.season_id},
        class: "select select-bordered w-full"
    end
  end

  def render_text_field(form, field, label, **opts)
    if @league.errors.include?(field)
      opts[:aria] = {invalid: true, describedby: "form-errors"}
    end
    div(class: "space-y-1") do
      form.label field, label, class: "label label-text font-medium"
      form.text_field field, required: true, class: "input w-full", **opts
    end
  end

  def render_datetime_field(form, field, label)
    div(class: "space-y-1", data: {controller: "local-datetime-field"}) do
      form.label field, label, class: "label label-text font-medium"
      form.datetime_local_field field,
        include_seconds: false, step: 60,
        class: "input w-full",
        data: {local_datetime_field_target: "input", action: "change->local-datetime-field#update"}
      input(type: "hidden", name: "league[time_zone]",
        data: {local_datetime_field_target: "timezone"})
      span(class: "label-text-alt text-xs opacity-70",
        data: {local_datetime_field_target: "hint"}) { "Detecting your timezone…" }
    end
  end

  def render_mode_fieldset(form)
    fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
      legend(class: "fieldset-legend text-sm font-medium") { "Draft style" }
      mode_radio(form, "live", "Live - each player picks on the clock")
      mode_radio(form, "manual", "Manual - I'll record both picks myself")

      div(class: "space-y-4 #{"hidden" unless @league.draft_mode == "live"}".strip,
        data_draft_mode_target: "liveOnly") do
        render_datetime_field(form, :draft_scheduled_at, "Draft date")
      end
    end
  end

  def mode_radio(form, value, copy)
    div(class: "space-y-1") do
      label(class: "label cursor-pointer justify-start gap-3") do
        form.radio_button :draft_mode, value,
          class: "radio radio-primary",
          data: {action: "change->draft-mode#sync"}
        span(class: "label-text") { copy }
      end
    end
  end

  def render_errors
    render Views::Components::ErrorAlert.new(messages: @errors, class_name: "mb-4")
  end
end
