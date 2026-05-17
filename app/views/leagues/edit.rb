# frozen_string_literal: true

class Views::Leagues::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo

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
            render_participant_order_section
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

  def render_draft_settings_link
    return unless @league_season
    div(class: "mt-4") do
      a(href: edit_league_draft_path(@league),
        class: "btn btn-ghost w-full justify-between") do
        span { "Draft settings →" }
        span(class: "text-xs opacity-60") { draft_settings_summary }
      end
    end
  end

  def draft_settings_summary
    parts = [@league_season.draft_mode.capitalize]
    if @league_season.draft_mode == "live" && @league_season.pick_clock_seconds
      parts << "#{@league_season.pick_clock_seconds}s clock"
    end
    parts.join(" · ")
  end

  def render_participant_order_section
    return unless @league_season

    fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3 mt-4") do
      legend(class: "fieldset-legend text-sm font-medium") { "Draft order" }
      if @league_season.draft_picks.any?
        p(class: "text-sm opacity-70") { "Draft has started — the order is locked." }
      else
        p(class: "text-xs opacity-60") do
          plain "Reorder seats before the draft begins. Position #1 picks first."
        end
        participants = @league_season.participants.to_a
        ul(class: "list bg-base-100 rounded-box border border-base-300") do
          participants.each_with_index do |p, idx|
            render_participant_row(p, first: idx.zero?, last: idx == participants.size - 1)
          end
        end
      end
    end
  end

  def render_participant_row(participant, first:, last:)
    li(class: "list-row flex items-center gap-3 px-3 py-2") do
      span(class: "badge badge-neutral") { "#" + participant.draft_position.to_s }
      span(class: "font-medium grow") do
        plain participant.display_name
        span(class: "badge badge-secondary badge-outline badge-sm ml-2") { "owner" } if participant.is_owner?
        span(class: "text-sm text-base-content/60 ml-2") { "(unclaimed)" } if participant.joined_at.nil?
      end
      div(class: "flex gap-1") do
        if first
          span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { "▲" }
        else
          button_to "▲", move_up_league_participant_path(@league, participant), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs",
            title: "Move up"
        end
        if last
          span(class: "btn btn-ghost btn-xs btn-disabled", aria_hidden: "true") { "▼" }
        else
          button_to "▼", move_down_league_participant_path(@league, participant), method: :patch,
            form: {class: "inline"},
            class: "btn btn-ghost btn-xs",
            title: "Move down"
        end
      end
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
