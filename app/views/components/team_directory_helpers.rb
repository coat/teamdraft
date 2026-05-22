# frozen_string_literal: true

# Shared rendering helpers for the team directory table - the same picker
# is used by the draft room (Views::Drafts::Show) and the post-draft
# standings (Views::Leagues::Show). Anything that's identical between the
# two phases lives here; per-phase column sets and filter form actions
# stay in the concrete views since they diverge.
#
# Including views must provide `@league_season` so `all_division_labels`
# can read its season teams.
module Views::Components::TeamDirectoryHelpers
  def render_team_swatch(team)
    if team.logo_url.present?
      img(src: team.logo_url, alt: "#{team.name} logo", width: 28, height: 28, class: "inline-block")
    else
      style = team.primary_color.present? ? "background-color: #{team.primary_color}" : nil
      span(
        class: "inline-flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold text-neutral-content bg-neutral",
        style: style
      ) { team.abbreviation.to_s[0, 3] }
    end
  end

  def render_directory_pick_cell(pick)
    if pick.nil?
      span(class: "opacity-50") { "-" }
    else
      span(class: "font-mono mr-1") { "##{pick.pick_number}" }
      span { pick.participant.display_name }
      if pick.autopicked
        span(class: "badge badge-xs badge-warning badge-outline ml-1") { "auto" }
      end
    end
  end

  def division_label(team)
    parts = [team.conference, team.division].compact_blank
    parts.empty? ? nil : parts.join(" ")
  end

  def all_division_labels
    @league_season.season.season_teams.includes(:team).map { |st| division_label(st.team) }.compact.uniq.sort
  end

  def status_option(value, label_text, current)
    option(value: value, selected: (value == current)) { label_text }
  end

  def division_option(value, label_text, current)
    option(value: value, selected: (value == current)) { label_text }
  end

  def render_empty_row(colspan)
    tr { td(colspan: colspan.to_s) { div(class: "alert alert-info my-2") { span { "No teams match these filters." } } } }
  end
end
