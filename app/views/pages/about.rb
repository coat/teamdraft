# frozen_string_literal: true

class Views::Pages::About < Views::Pages::Base
  def initialize(sports:, active_sport:)
    @sports = sports
    @active_sport = active_sport
  end

  def page_title = "About"

  def body
    p do
      plain "Team Draft is a 2-player fantasy league where you and a friend take turns picking entire teams instead of individual players. As the season unfolds, your teams score you points for wins and playoff runs."
    end

    h2 { "How it works" }
    ol do
      li { "Start a league and share the link with a friend." }
      li { "Take turns picking teams (live with a clock, or manually offline)." }
      li { "Watch points roll in as the games play out." }
    end

    h2 { "Scoring" }

    if @sports.size > 1
      render_sport_tabs
    end

    if @active_sport
      render_blurb(@active_sport)
      render_scoring_table(@active_sport)
    else
      p { "No sports configured yet." }
    end
  end

  private

  def render_sport_tabs
    div(role: "tablist", class: "tabs tabs-boxed w-fit mb-3") do
      @sports.each do |sport|
        active = (sport.id == @active_sport&.id)
        classes = ["tab"]
        classes << "tab-active" if active
        a(href: about_path(sport: sport.key),
          role: "tab",
          class: classes.join(" "),
          aria_selected: active.to_s) { sport.name }
      end
    end
  end

  def render_blurb(sport)
    return if sport.about_blurb.blank?
    p(class: "text-base-content/70 mb-2") { sport.about_blurb }
  end

  def render_scoring_table(sport)
    rules = sport.scoring_rules.ordered
    p(class: "text-sm text-base-content/60 mb-2") { "Playoff points stack — each round you reach adds to your total." }
    div(class: "overflow-x-auto") do
      table(class: "table table-sm") do
        thead do
          tr do
            th { "Event" }
            th(class: "text-right") { "Points" }
          end
        end
        tbody do
          rules.each do |rule|
            tr do
              td { rule.label }
              td(class: "text-right font-mono") { rule.points.to_s }
            end
          end
        end
      end
    end
  end
end
