# frozen_string_literal: true

# Shared form fields for both New and Edit. Subclass passes the form_with
# args (url + method) via the block - keeps the inputs in one place so
# changes don't drift between new and edit.
class Views::Admin::Seasons::Form < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(season:, sports:, url:, method:)
    @season = season
    @sports = sports
    @url = url
    @method = method
  end

  def view_template
    render Views::Components::ErrorAlert.new(records: @season)

    form_with(model: @season, url: @url, method: @method, scope: :season, class: "space-y-3") do |f|
      select_row(f, :sport_id, "Sport", @sports, required: true)
      number_row(f, :year, "Year", min: 1900, max: 2100, required: true)
      text_row(f, :label, "Label (e.g. \"NFL 2026\")", required: true)
      select_row(f, :status, "Status", Season::STATUSES.map { |s| [s.titleize, s] })
      date_row(f, :starts_on, "Starts on")
      date_row(f, :ends_on, "Ends on")
      text_row(f, :external_provider, "External provider (e.g. \"thesportsdb\")")
      text_row(f, :external_id, "External ID (provider's season key)")
      div(class: "card-actions justify-end pt-2") do
        a(href: admin_seasons_path, class: "btn btn-ghost") { "Cancel" }
        f.submit "Save", class: "btn btn-primary"
      end
    end
  end

  private

  def text_row(f, name, label, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.text_field name, class: "input w-full", **opts
    end
  end

  def number_row(f, name, label, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.number_field name, class: "input w-full", **opts
    end
  end

  def date_row(f, name, label, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.date_field name, class: "input w-full", **opts
    end
  end

  def select_row(f, name, label, options, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.select name, options, {include_blank: opts.delete(:include_blank)}, class: "select w-full", **opts
    end
  end
end
