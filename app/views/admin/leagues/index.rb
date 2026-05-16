# frozen_string_literal: true

class Views::Admin::Leagues::Index < Views::Base
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(leagues:)
    @leagues = leagues
  end

  def view_template
    render Views::Layouts::Application.new(title: "Admin · Leagues") do
      main(class: "py-6 space-y-4") do
        h1(class: "text-3xl font-bold") { "Leagues" }
        p(class: "text-sm text-base-content/70") do
          plain "Each row reflects the league's current season. Destructive controls: edit fields (including status), or delete the entire league. Deletion cascades to every season's participants and draft picks."
        end
        div(class: "card bg-base-100 shadow") do
          div(class: "overflow-x-auto") do
            table(class: "table table-sm table-zebra") do
              thead do
                tr do
                  th { "Name" }
                  th { "Current season" }
                  th { "Status" }
                  th { "Size" }
                  th { "Draft" }
                  th { "Pick #" }
                  th { "Owner" }
                  th { "Users" }
                  th
                end
              end
              tbody do
                @leagues.each { |league| render_row(league) }
              end
            end
          end
        end
      end
    end
  end

  private

  def render_row(league)
    ls = league.current_league_season
    participants = ls ? ls.participants.to_a : []
    user_count = participants.count { |p| p.user_id }
    tr(class: (user_count.zero? ? "bg-warning/10" : nil)) do
      td(class: "font-medium") { league.name }
      td(class: "text-sm") { ls&.season&.label || "—" }
      td { ls ? render_status(ls.status) : plain("—") }
      td(class: "font-mono") { ls ? "#{participants.size}/#{ls.size}" : "—" }
      td(class: "text-sm") { ls ? "#{ls.draft_mode} · #{ls.draft_order_style}" : "—" }
      td(class: "font-mono") { ls&.current_pick_number.to_s }
      td(class: "text-sm") { owner_label(participants) }
      td { render_user_badge(user_count, participants.size) }
      td(class: "flex flex-wrap gap-1 justify-end") do
        a(href: edit_admin_league_path(league), class: "btn btn-ghost btn-xs") { "Edit" }
        button_to "Delete", admin_league_path(league),
          method: :delete,
          form: {class: "inline", data: {turbo_confirm: "Delete #{league.name}? This removes every season's participants and draft picks."}},
          class: "btn btn-error btn-xs"
      end
    end
  end

  def render_status(status)
    color = {
      "draft_pending" => "badge-ghost",
      "drafting" => "badge-warning",
      "in_season" => "badge-success",
      "completed" => "badge-info"
    }[status]
    span(class: "badge badge-sm #{color}") { status }
  end

  def render_user_badge(user_count, total)
    if total.zero?
      span(class: "opacity-50") { "—" }
    elsif user_count.zero?
      span(class: "badge badge-sm badge-warning") { "anonymous" }
    else
      color = (user_count == total) ? "badge-success" : "badge-info"
      span(class: "badge badge-sm #{color}") { "#{user_count}/#{total} signed up" }
    end
  end

  def owner_label(participants)
    owner = participants.find { |p| p.is_owner }
    return span(class: "opacity-50") { "—" } unless owner
    owner.user&.email_address || owner.display_name
  end
end
