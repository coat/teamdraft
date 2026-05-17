# frozen_string_literal: true

# The "create a league" form, used on the landing page and at /leagues/new.
# Posts to LeaguesController#create. Pick clock + scheduled date are only
# meaningful for live drafts; the draft-mode Stimulus controller hides them
# when "manual" is selected.
class Views::Leagues::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(league:, errors: [], submit_label: "Create league")
    @league = league
    @errors = errors
    @submit_label = submit_label
  end

  def view_template
    render_errors if @errors.any?

    form_with(model: @league, url: leagues_path, method: :post, scope: :league,
      class: "space-y-4", data: {controller: "draft-mode"}) do |form|
      render_text_field(form, :your_name, "Your name", autocomplete: "given-name")
      render_text_field(form, :opponent_name, "Opponent's name")
      render_mode_fieldset(form)

      div(class: "space-y-4 #{"hidden" unless @league.draft_mode == "live"}".strip,
        data_draft_mode_target: "liveOnly") do
        render_datetime_field(form, :draft_scheduled_at, "Draft date")
        render_pick_clock_field(form)
      end

      div(class: "card-actions justify-end pt-1") do
        form.submit @submit_label, class: "btn btn-primary"
      end
    end
  end

  private

  def render_text_field(form, field, label, **opts)
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
      span(class: "label-text-alt text-xs opacity-60",
        data: {local_datetime_field_target: "hint"}) { "Detecting your timezone…" }
    end
  end

  def render_mode_fieldset(form)
    fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
      legend(class: "fieldset-legend text-sm font-medium") { "Draft style" }
      mode_radio(form, "manual", "Manual — I'll record both picks myself")
      mode_radio(form, "live", "Live — each player picks on the clock")
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

  def render_pick_clock_field(form)
    div(class: "space-y-1") do
      form.label :pick_clock_seconds, "Pick clock (seconds)", class: "label label-text font-medium"
      form.number_field :pick_clock_seconds, value: @league.pick_clock_seconds || 60,
        min: 10, step: 5, class: "input w-32"
    end
  end

  def render_errors
    div(class: "alert alert-error mb-4", role: "alert") do
      ul(class: "list-disc list-inside") do
        @errors.each { |msg| li { msg } }
      end
    end
  end
end
