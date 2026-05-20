# frozen_string_literal: true

# Sync controls for a single season: pull games from the configured
# external provider (optionally scoped to a round) + recompute scoring
# events from local game data. Used on the admin dashboard for active
# seasons, and on the per-season show page for backfilling history.
#
# The form carries a hidden `redirect_to` so the post-sync redirect
# returns the user to wherever they were when they clicked the button
# (whitelisted server-side to /admin paths).
class Views::Components::Admin::SyncActions < Views::Base
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::FormWith

  def initialize(season:, back_path:)
    @season = season
    @back_path = back_path
  end

  def view_template
    div(class: "border border-base-300 rounded-lg p-3 space-y-2") do
      h3(class: "font-medium") { @season.label }
      div(class: "flex flex-col gap-2") do
        render_round_form
        render_date_range_form
        button_to "Recompute scoring",
          admin_syncs_path,
          params: {kind: "scoring", season_id: @season.id, redirect_to: @back_path},
          form: {class: "inline"}, class: "btn btn-sm w-fit"
      end
    end
  end

  private

  def render_round_form
    form_with(url: admin_syncs_path, method: :post, class: "flex flex-wrap gap-2 items-center") do |form|
      form.hidden_field :kind, value: "games"
      form.hidden_field :season_id, value: @season.id
      form.hidden_field :redirect_to, value: @back_path
      form.select :round,
        [["All rounds", ""]] + SportsData::Provider.for(@season).round_labels.map { |k, v| [v, k] },
        {},
        class: "select select-sm select-bordered"
      form.submit "Pull games from #{@season.external_provider.presence || "thesportsdb"}",
        class: "btn btn-sm"
    end
  end

  def render_date_range_form
    from_default = (@season.starts_on || Date.current).iso8601
    to_default = Date.current.iso8601
    form_with(url: admin_syncs_path, method: :post, class: "flex flex-wrap gap-2 items-center") do |form|
      form.hidden_field :kind, value: "games"
      form.hidden_field :season_id, value: @season.id
      form.hidden_field :redirect_to, value: @back_path
      span(class: "text-sm") { "from" }
      form.date_field :dates_from, value: from_default, class: "input input-sm input-bordered"
      span(class: "text-sm") { "to" }
      form.date_field :dates_to, value: to_default, class: "input input-sm input-bordered"
      form.submit "Pull by date range", class: "btn btn-sm"
    end
  end
end
