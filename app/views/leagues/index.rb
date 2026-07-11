# frozen_string_literal: true

class Views::Leagues::Index < Views::Base
  def initialize(participants:)
    @participants = participants
  end

  def view_template
    render Views::Layouts::Application.new(title: "Your leagues") do
      main(class: "py-6 space-y-4") do
        div(class: "flex items-center justify-between") do
          h1(class: "text-3xl font-bold") { "Your leagues" }
          a(href: new_league_path, class: "btn btn-primary btn-sm") { "Start a new league" }
        end

        div(class: "space-y-3") do
          sorted_participants.each { |participant| render_league_card(participant) }
        end
      end
    end
  end

  private

  def sorted_participants
    @participants.sort_by { |p| status_rank(p.league_season.status) }
  end

  def status_rank(status)
    case status
    when "drafting" then 0
    when "in_season" then 1
    when "draft_pending" then 2
    when "completed" then 3
    else 4
    end
  end

  def render_league_card(participant)
    league = participant.league_season.league
    ls = participant.league_season
    a(
      href: league_path(league),
      class: "block group rounded-box focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
    ) do
      div(class: "card bg-base-100 shadow transition hover:shadow-lg hover:-translate-y-0.5 cursor-pointer") do
        div(class: "card-body") do
          div(class: "flex items-start justify-between gap-3") do
            h2(class: "card-title flex items-center gap-1") do
              plain league.name
              render Views::Components::Icon.new(
                :chevron_right,
                class_name: "size-5 text-base-content/60 group-hover:text-base-content group-hover:translate-x-0.5 transition"
              )
            end
            span(class: status_badge_class(ls.status)) { render_status_label(ls) }
          end
          render_summary(ls, participant)
        end
      end
    end
  end

  def status_badge_class(status)
    base = "badge"
    case status
    when "drafting" then "#{base} badge-primary"
    when "in_season" then "#{base} badge-success"
    when "draft_pending" then "#{base} badge-warning"
    when "completed" then "#{base} badge-ghost"
    else base
    end
  end

  def render_status_label(ls)
    case ls.status
    when "draft_pending" then render_pending_label(ls)
    when "drafting" then plain "Drafting (pick ##{ls.current_pick_number} of #{ls.total_picks})"
    when "in_season" then plain "In season"
    when "completed" then plain "Completed"
    end
  end

  def render_pending_label(ls)
    if ls.draft_scheduled_at.present? && ls.draft_scheduled_at > Time.current
      plain "Drafts "
      time(datetime: ls.draft_scheduled_at.iso8601, data: {controller: "local-time"}) do
        plain ls.draft_scheduled_at.strftime("%a %b %-d at %-l:%M %p %Z")
      end
    elsif ls.participants.where(joined_at: nil).any?
      plain "Awaiting opponent"
    else
      plain "Draft pending"
    end
  end

  def render_summary(ls, current_participant)
    return if ls.status == "draft_pending"
    rows = Standings::Calculate.call(league_season: ls)
    div(class: "overflow-x-auto mt-2") do
      table(class: "table table-sm") do
        tbody do
          rows.each do |row|
            is_you = (row.participant.id == current_participant.id)
            tr(class: is_you ? "bg-primary/5" : nil) do
              td(class: is_you ? "font-medium" : nil) { row.participant.display_name }
              td(class: "text-right") { "#{row.total_points} pts" }
            end
          end
        end
      end
    end
  end
end
