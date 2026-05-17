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
      div(class: "flex flex-wrap gap-2 items-center") do
        form_with(url: admin_syncs_path, method: :post, class: "inline-flex gap-2 items-center") do |form|
          form.hidden_field :kind, value: "games"
          form.hidden_field :season_id, value: @season.id
          form.hidden_field :redirect_to, value: @back_path
          form.select :round,
            [["All rounds", ""]] + SportsData::TheSportsDbProvider::ROUND_LABELS.map { |k, v| [v, k] },
            {},
            class: "select select-sm select-bordered"
          form.submit "Pull games from #{@season.external_provider.presence || "thesportsdb"}",
            class: "btn btn-sm"
        end
        button_to "Recompute scoring",
          admin_syncs_path,
          params: {kind: "scoring", season_id: @season.id, redirect_to: @back_path},
          form: {class: "inline"}, class: "btn btn-sm"
      end
    end
  end
end
