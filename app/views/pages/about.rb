# frozen_string_literal: true

class Views::Pages::About < Views::Pages::Base
  def page_title = "About"

  def body
    p do
      plain "Team Draft is a 2-player fantasy league inspired by the "
      a(href: "https://www.espn.com/radio/play/_/id/46093555", target: "_blank", rel: "noopener", class: "link") { "Mina Kimes Show's" }
      plain " yearly NFL team draft. Instead of drafting individual players, you and a friend take turns picking entire NFL teams. As the season unfolds, your teams score you points for wins and playoff runs."
    end

    h2 { "How it works" }
    ol do
      li { "Start a league and share the link with a friend." }
      li { "Take turns picking teams (live with a clock, or manually offline)." }
      li { "Watch points roll in as the games play out." }
    end

    h2 { "Scoring (NFL)" }
    p { "Playoff points stack — each round you reach adds to your total." }
    render_scoring_table
    p(class: "text-sm text-base-content/60") do
      plain "A team that wins the Super Bowl is worth 35 playoff points (plus its regular-season wins). A team that misses the playoffs only earns its regular-season wins."
    end
  end

  private

  def render_scoring_table
    rules = Scoring::Rules::DEFAULTS.fetch("nfl")
    table(class: "table table-sm") do
      thead do
        tr do
          th { "Event" }
          th(class: "text-right") { "Points" }
        end
      end
      tbody do
        scoring_rows.each do |key, label|
          tr do
            td { label }
            td(class: "text-right font-mono") { rules.fetch(key).to_s }
          end
        end
      end
    end
  end

  def scoring_rows
    [
      ["regular_win", "Regular-season win"],
      ["playoff_appearance", "Made the playoffs"],
      ["divisional_appearance", "Made the divisional round"],
      ["conference_appearance", "Made the conference championship"],
      ["championship_appearance", "Made the Super Bowl"],
      ["championship_win", "Won the Super Bowl"]
    ]
  end
end
