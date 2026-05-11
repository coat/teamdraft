# frozen_string_literal: true

class Views::Admin::Teams::Index < Views::Base
  def initialize(teams:)
    @teams = teams
  end

  def view_template
    render Views::Layouts::Application.new(title: "Admin · Teams") do
      main(class: "py-6 space-y-4") do
        h1(class: "text-3xl font-bold") { "Teams" }
        p(class: "text-sm text-base-content/70") do
          plain "External ID is what links a team to its provider (e.g. TheSportsDB's idTeam). Required for game sync."
        end
        div(class: "card bg-base-100 shadow") do
          div(class: "overflow-x-auto") do
            table(class: "table table-sm") do
              thead do
                tr do
                  th { "Sport" }
                  th { "Name" }
                  th { "Abbr" }
                  th { "Conf/Div" }
                  th { "External ID" }
                  th { "Pick rank" }
                  th
                end
              end
              tbody do
                @teams.each { |team| render_row(team) }
              end
            end
          end
        end
      end
    end
  end

  private

  def render_row(team)
    tr(class: team.external_id.blank? ? "bg-warning/10" : nil) do
      td { team.sport.key }
      td(class: "font-medium") { team.name }
      td { team.abbreviation }
      td { "#{team.conference}/#{team.division}" }
      td { team.external_id.presence || span(class: "opacity-50") { "—" } }
      td { team.default_pick_rank&.to_s || span(class: "opacity-50") { "—" } }
      td { a(href: edit_admin_team_path(team), class: "btn btn-ghost btn-xs") { "Edit" } }
    end
  end
end
