# frozen_string_literal: true

module Seasons
  # Sort-aware wrapper around `Seasons::TeamStandings` for the
  # /seasons/:sport_key/:year show page. Mirrors `Leagues::DirectoryQuery`
  # in shape (whitelisted sort columns + `to_url_params`) so the same
  # `SortableHeader` component can drive both tables. Also tracks which
  # teams view (flat standings vs by division) the URL selects.
  class StandingsQuery
    SORTS = %w[name division record points].freeze
    VIEWS = %w[standings division].freeze
    URL_PARAM_KEYS = %i[sort dir view].freeze

    def self.from_request(season:, params:)
      new(season: season, params: params.permit(*URL_PARAM_KEYS))
    end

    def initialize(season:, params: {})
      @season = season
      @params = params || {}
    end

    attr_reader :season, :params

    def rows
      sorted = base_rows.sort_by.with_index { |r, i| [sort_key(r), i] }
      # String-only sorts reverse the whole result for desc; numeric
      # sorts bake the sign into the key (see sort_key) so the name
      # tiebreaker stays alphabetical regardless of direction.
      sorted.reverse! if sort_dir == "desc" && %w[name division].include?(sort_column)
      sorted
    end

    def sort_column
      col = params[:sort].to_s
      SORTS.include?(col) ? col : "points"
    end

    def sort_dir
      explicit = params[:dir].to_s
      return explicit if %w[asc desc].include?(explicit)
      %w[name division].include?(sort_column) ? "asc" : "desc"
    end

    def view
      v = params[:view].to_s
      VIEWS.include?(v) ? v : "standings"
    end

    def to_url_params(overrides = {})
      # The default view stays out of URLs so /seasons/nfl/2025 remains canonical.
      view_param = (view == "standings") ? nil : view
      {sort: sort_column, dir: sort_dir, view: view_param}.merge(overrides).compact_blank
    end

    private

    def base_rows
      @base_rows ||= Seasons::TeamStandings.call(season: @season)
    end

    def sort_key(row)
      sign = (sort_dir == "desc") ? -1 : 1
      name = row.team.name.downcase
      case sort_column
      when "name"
        [name]
      when "division"
        [[row.team.conference, row.team.division].compact.join(" "), name]
      when "record"
        wins = row.reg_w + row.po_w
        losses = row.reg_l + row.po_l
        [sign * wins, -sign * losses, name]
      else
        [sign * row.points, sign * row.po_w, sign * row.reg_w, name]
      end
    end
  end
end
