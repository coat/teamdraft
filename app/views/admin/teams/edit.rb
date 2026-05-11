# frozen_string_literal: true

class Views::Admin::Teams::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(team:)
    @team = team
  end

  def view_template
    render Views::Layouts::Application.new(title: "Edit team · Admin") do
      main(class: "py-6") do
        div(class: "card bg-base-100 shadow") do
          div(class: "card-body") do
            h1(class: "card-title text-2xl") { "Edit #{@team.name}" }

            if @team.errors.any?
              div(class: "alert alert-error", role: "alert") do
                ul(class: "list-disc list-inside") {
                  @team.errors.full_messages.each { |m| li { m } }
                }
              end
            end

            form_with(model: @team, url: admin_team_path(@team), method: :patch, class: "space-y-3") do |f|
              text_field_row(f, :name, "Name", required: true)
              text_field_row(f, :abbreviation, "Abbreviation", required: true)
              text_field_row(f, :external_id, "External ID (provider id)")
              number_field_row(f, :default_pick_rank, "Default pick rank (1 = best)", min: 1)
              text_field_row(f, :conference, "Conference")
              text_field_row(f, :division, "Division")
              text_field_row(f, :primary_color, "Primary color")
              text_field_row(f, :logo_url, "Logo URL")
              div(class: "card-actions justify-end pt-2") do
                a(href: admin_teams_path, class: "btn btn-ghost") { "Cancel" }
                f.submit "Save", class: "btn btn-primary"
              end
            end
          end
        end
      end
    end
  end

  private

  def text_field_row(f, name, label, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.text_field name, class: "input w-full", **opts
    end
  end

  def number_field_row(f, name, label, **opts)
    div(class: "space-y-1") do
      f.label name, label, class: "label label-text font-medium"
      f.number_field name, class: "input w-full", **opts
    end
  end
end
