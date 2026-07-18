# frozen_string_literal: true

class Views::Admin::Leagues::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(league:, league_season:)
    @league = league
    @league_season = league_season
  end

  def view_template
    render Views::Layouts::Admin.new(
      title: "Edit #{@league.name}",
      section: :leagues,
      breadcrumbs: [
        ["Leagues", admin_leagues_path],
        [@league.name, admin_league_path(@league)],
        ["Edit", nil]
      ]
    ) do
      render Views::Components::Admin::PageHeader.new(
        title: "Edit #{@league.name}",
        subtitle: "Current season: #{@league_season&.season&.label || "-"}"
      )
      div(class: "card bg-base-100 shadow") do
        div(class: "card-body") do
          render_participants

          render Views::Components::ErrorAlert.new(records: [@league, @league_season])

          form_with(url: admin_league_path(@league), method: :patch, class: "space-y-3 mt-3") do |f|
            fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
              legend(class: "fieldset-legend text-sm font-medium") { "League (durable)" }
              text_field_row("league[name]", "Name", @league.name, required: true)
            end

            if @league_season
              fieldset(class: "fieldset border border-base-300 rounded-lg p-4 space-y-3") do
                legend(class: "fieldset-legend text-sm font-medium") { "Current season state" }
                number_field_row("league_season[size]", "Size (2–8)", @league_season.size, min: 2, max: 8, required: true)
                select_field_row("league_season[draft_mode]", "Draft mode", @league_season.draft_mode, LeagueSeason::DRAFT_MODES.map { |m| [m, m] })
                select_field_row("league_season[draft_order_style]", "Draft order style", @league_season.draft_order_style, LeagueSeason::DRAFT_ORDER_STYLES.map { |s| [s, s] })
                select_field_row("league_season[status]", "Status", @league_season.status, LeagueSeason::STATUSES.map { |s| [s, s] })
                number_field_row("league_season[current_pick_number]", "Current pick #", @league_season.current_pick_number, min: 1, required: true)
                number_field_row("league_season[pick_clock_seconds]", "Pick clock (seconds, blank for none)", @league_season.pick_clock_seconds, min: 1)
              end
            end

            div(class: "card-actions justify-end pt-2") do
              a(href: admin_leagues_path, class: "btn btn-ghost") { "Cancel" }
              f.submit "Save", class: "btn btn-primary"
            end
          end
        end
      end
    end
  end

  private

  def render_participants
    return unless @league_season
    div(class: "mt-3 space-y-1") do
      h2(class: "font-medium text-sm uppercase tracking-wide opacity-70") { "Participants" }
      ul(class: "text-sm space-y-1") do
        @league_season.participants.each do |p|
          li(class: "flex items-center gap-2") do
            span(class: "font-medium") { p.display_name }
            if p.user_id
              span(class: "badge badge-sm badge-success") { p.user&.email_address || "user ##{p.user_id}" }
            else
              span(class: "badge badge-sm badge-warning") { "anonymous" }
            end
            span(class: "badge badge-sm badge-ghost") { "owner" } if p.is_owner
          end
        end
      end
    end
  end

  def text_field_row(name, label_text, value, **opts)
    div(class: "space-y-1") do
      label(for: name, class: "label label-text font-medium") { label_text }
      input(type: "text", name: name, id: name, value: value, class: "input w-full", **opts)
    end
  end

  def number_field_row(name, label_text, value, **opts)
    div(class: "space-y-1") do
      label(for: name, class: "label label-text font-medium") { label_text }
      input(type: "number", name: name, id: name, value: value, class: "input w-full", **opts)
    end
  end

  def select_field_row(name, label_text, value, options)
    div(class: "space-y-1") do
      label(for: name, class: "label label-text font-medium") { label_text }
      select(name: name, id: name, class: "select w-full") do
        options.each do |label_str, val|
          option(value: val, selected: (val == value)) { label_str }
        end
      end
    end
  end
end
