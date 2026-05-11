# frozen_string_literal: true

class Views::Pages::Home < Views::Base
  def initialize(league:)
    @league = league
  end

  def view_template
    # no-preview keeps Turbo Drive from flashing the anonymous landing
    # page snapshot before the server-side redirect lands a logged-in
    # user on their league.
    render Views::Layouts::Application.new(title: "Team Draft", turbo_cache_control: "no-preview") do
      main(class: "py-8 space-y-6") do
        render_hero
        render_quick_start
      end
    end
  end

  private

  def render_hero
    div(class: "text-base-content space-y-3") do
      p(class: "text-base-content/70 max-w-xl mx-auto") do
        plain "Welcome! Team Draft is a 2-person fantasy sports league, where you draft entire sports teams - not players - and score points throughout the season based on wins and playoff appearances. The idea was taken from the "
        a(href: "https://www.espn.com/radio/play/_/id/46093555", class: "link link-primary") { "Mina Kimes Show's yearly NFL Team Draft" }
        plain ". "
      end

      p(class: "text-base-content/70 max-w-xl mx-auto") do
        plain "Get started now - no need to register an account. "
        a(href: about_path, class: "link link-primary") { "More info" }
      end
    end
  end

  def render_quick_start
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title") { "Start a draft" }

        render Views::Leagues::Form.new(league: @league, submit_label: "Start drafting")
      end
    end
  end
end
