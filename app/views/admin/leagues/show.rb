# frozen_string_literal: true

class Views::Admin::Leagues::Show < Views::Base
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(league:)
    @league = league
    @current_season = league.current_league_season
    @participants = @current_season ? @current_season.participants.to_a : []
  end

  def view_template
    render Views::Layouts::Admin.new(
      title: @league.name,
      section: :leagues,
      breadcrumbs: [["Leagues", admin_leagues_path], [@league.name, nil]]
    ) do
      render Views::Components::Admin::PageHeader.new(
        title: @league.name,
        subtitle: "Created #{@league.created_at.strftime("%Y-%m-%d")}"
      ) do
        if @league.private?
          span(class: "badge badge-ghost") { "private" }
        end
        a(href: league_path(@league), class: "btn btn-ghost btn-sm") { "View public" }
        a(href: edit_admin_league_path(@league), class: "btn btn-ghost btn-sm inline-flex items-center gap-1") do
          render Views::Components::Icon.new(:pencil_square)
          plain "Edit"
        end
        button_to admin_league_path(@league),
          method: :delete,
          form: {class: "inline", data: {turbo_confirm: "Delete #{@league.name}? This removes every season's participants and draft picks."}},
          class: "btn btn-error btn-sm inline-flex items-center gap-1" do
          render Views::Components::Icon.new(:trash)
          plain "Delete"
        end
      end

      render_current_season
      render_participants
      render_seasons
    end
  end

  private

  def render_current_season
    return unless @current_season
    div(class: "card bg-base-100 shadow") do
      div(class: "card-body") do
        h2(class: "card-title text-base") { "Current season" }
        dl(class: "grid grid-cols-2 sm:grid-cols-4 gap-3 mt-2 text-sm") do
          stat("Season", @current_season.season.label)
          stat("Status", @current_season.status)
          stat("Size", @current_season.size.to_s)
          stat("Draft mode", @current_season.draft_mode)
        end
      end
    end
  end

  def render_participants
    render Views::Components::Admin::RelatedPanel.new(title: "Participants (#{@participants.size})") do
      if @participants.empty?
        p(class: "text-sm text-base-content/70") { "None yet." }
      else
        ul(class: "menu bg-base-100 w-full p-0 [&_li>*]:rounded-lg") do
          @participants.each do |p|
            li do
              if p.user_id && p.user
                a(href: admin_user_path(p.user)) do
                  span(class: "font-medium") { p.display_name }
                  span(class: "text-xs opacity-70 ml-2") { p.user.email_address }
                  if p.is_owner
                    span(class: "badge badge-xs badge-ghost ml-1") { "owner" }
                  end
                end
              else
                span do
                  span(class: "font-medium") { p.display_name }
                  span(class: "badge badge-xs badge-warning ml-2") { "anonymous" }
                  if p.is_owner
                    span(class: "badge badge-xs badge-ghost ml-1") { "owner" }
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def render_seasons
    seasons = @league.league_seasons.includes(:season).order("seasons.year desc").to_a
    render Views::Components::Admin::RelatedPanel.new(title: "Seasons (#{seasons.size})") do
      ul(class: "menu bg-base-100 w-full p-0 [&_li>*]:rounded-lg") do
        seasons.each do |ls|
          li do
            a(href: admin_season_path(ls.season)) do
              span(class: "font-medium") { ls.season.label }
              span(class: "text-xs opacity-70 ml-2") { ls.status }
            end
          end
        end
      end
    end
  end

  def stat(label_text, value)
    div do
      dt(class: "text-xs uppercase tracking-wide opacity-70") { label_text }
      dd(class: "font-medium") { value.to_s }
    end
  end
end
