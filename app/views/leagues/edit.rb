# frozen_string_literal: true

class Views::Leagues::Edit < Views::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(league:)
    @league = league
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

            render_errors if @league.errors.any?

            form_with(model: @league, url: league_path(@league), method: :patch, scope: :league, class: "space-y-3 mt-3") do |form|
              div(class: "space-y-1") do
                form.label :name, "Name", class: "label label-text font-medium"
                form.text_field :name, value: @league.name, required: true,
                  class: "input w-full"
              end
              div(class: "card-actions justify-end pt-2") do
                a(href: league_path(@league), class: "btn btn-ghost") { "Cancel" }
                form.submit "Save changes", class: "btn btn-primary"
              end
            end
          end
        end
      end
    end
  end

  private

  def render_errors
    div(class: "alert alert-error mt-3", role: "alert") do
      ul(class: "list-disc list-inside") do
        @league.errors.full_messages.each { |msg| li { msg } }
      end
    end
  end

  def history_hint
    history = @league.slugs.where.not(slug: @league.slug).limit(2).pluck(:slug)
    return "" if history.empty?
    " (e.g. " + history.map { |s| "/leagues/#{s}" }.join(", ") + ")"
  end
end
