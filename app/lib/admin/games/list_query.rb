# frozen_string_literal: true

module Admin
  module Games
    # Encapsulates the filter/sort logic behind /admin/games, including the
    # season fallback chain (param, then active season, then first season).
    # Whitelists sort columns and directions so unsanitized user input can
    # never reach the SQL ORDER BY.
    class ListQuery
      SORTS = {
        "starts_at" => "games.starts_at",
        "round" => "games.round",
        "week" => "games.week",
        "status" => "games.status"
      }.freeze

      ORDER_CLAUSES = SORTS.each_with_object({}) do |(key, col), memo|
        memo[[key, "asc"]] = Arel.sql("#{col} asc NULLS LAST")
        memo[[key, "desc"]] = Arel.sql("#{col} desc NULLS LAST")
      end.freeze

      def initialize(params = {})
        @params = params || {}
      end

      attr_reader :params

      def relation
        return Game.none unless season
        scope = season.games.includes(home_season_team: :team, away_season_team: :team)
        scope = filter_by_status(scope)
        scope = filter_by_round(scope)
        scope = filter_by_week(scope)
        scope = filter_by_team(scope)
        scope = filter_by_dates(scope)
        scope.order(ORDER_CLAUSES.fetch([sort_column, sort_dir])).order(:id)
      end

      def season
        return @season if defined?(@season)
        id = params[:season_id].presence || Season.where(status: "active").pick(:id) || Season.first&.id
        @season = id && Season.find_by(id: id)
      end

      def season_id
        season&.id
      end

      def status
        value = params[:status].to_s.presence
        Game::STATUSES.include?(value) ? value : nil
      end

      def round
        params[:round].to_s.strip.presence
      end

      def week
        value = params[:week].to_s.strip
        value.match?(/\A\d+\z/) ? value.to_i : nil
      end

      def team_id
        params[:team_id].to_s.presence
      end

      def from
        parse_date(params[:from])
      end

      def to
        parse_date(params[:to])
      end

      def sort_column
        col = params[:sort].to_s
        SORTS.key?(col) ? col : "starts_at"
      end

      def sort_dir
        (params[:dir].to_s == "desc") ? "desc" : "asc"
      end

      # Builds a hash of current state plus any overrides. Used by the filter
      # form, sortable header links, and pagination to preserve URL state.
      def to_url_params(overrides = {})
        {
          season_id: season_id,
          status: status,
          round: round,
          week: week,
          team_id: team_id,
          from: from&.iso8601,
          to: to&.iso8601,
          sort: sort_column,
          dir: sort_dir
        }.merge(overrides).compact_blank
      end

      private

      def parse_date(value)
        Date.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def filter_by_status(scope)
        status ? scope.where(status: status) : scope
      end

      def filter_by_round(scope)
        round ? scope.where(round: round) : scope
      end

      def filter_by_week(scope)
        week ? scope.where(week: week) : scope
      end

      def filter_by_team(scope)
        return scope unless team_id
        season_team_id = season.season_teams.where(team_id: team_id).pick(:id)
        return scope.none unless season_team_id
        scope.where(
          "games.home_season_team_id = :id OR games.away_season_team_id = :id",
          id: season_team_id
        )
      end

      def filter_by_dates(scope)
        scope = scope.where(starts_at: from.beginning_of_day..) if from
        scope = scope.where(starts_at: ..to.end_of_day) if to
        scope
      end
    end
  end
end
