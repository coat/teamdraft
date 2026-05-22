# frozen_string_literal: true

module Admin
  module Leagues
    # Encapsulates the filter/sort logic behind /admin/leagues. The controller
    # reads incoming params, hands them to this object, and gets back a
    # paginatable ActiveRecord relation. Whitelists sort columns and directions
    # so unsanitized user input can never reach the SQL ORDER BY.
    class ListQuery
      SORTS = {
        "name" => "leagues.name",
        "created_at" => "leagues.created_at"
      }.freeze

      ORDER_CLAUSES = SORTS.each_with_object({}) do |(key, col), memo|
        memo[[key, "asc"]] = Arel.sql("#{col} asc")
        memo[[key, "desc"]] = Arel.sql("#{col} desc")
      end.freeze

      USER_FILTERS = %w[yes no].freeze

      def initialize(params = {})
        @params = params || {}
      end

      attr_reader :params

      def relation
        scope = base_relation
        scope = filter_by_name(scope)
        scope = filter_by_status(scope)
        scope = filter_by_users(scope)
        scope.order(ORDER_CLAUSES.fetch([sort_column, sort_dir]))
      end

      def search_term
        params[:q].to_s.strip.presence
      end

      def status
        value = params[:status].to_s.presence
        LeagueSeason::STATUSES.include?(value) ? value : nil
      end

      def users
        value = params[:users].to_s.presence
        USER_FILTERS.include?(value) ? value : nil
      end

      def sort_column
        col = params[:sort].to_s
        SORTS.key?(col) ? col : "name"
      end

      def sort_dir
        (params[:dir].to_s == "desc") ? "desc" : "asc"
      end

      # Builds a hash of current state plus any overrides. Used by the filter
      # form, sortable header links, and pagination to preserve URL state.
      def to_url_params(overrides = {})
        {
          q: search_term,
          status: status,
          users: users,
          sort: sort_column,
          dir: sort_dir
        }.merge(overrides).compact_blank
      end

      private

      def base_relation
        League.includes(league_seasons: [:season, {participants: :user}])
      end

      def filter_by_name(scope)
        return scope unless search_term
        like = "%#{ActiveRecord::Base.sanitize_sql_like(search_term)}%"
        scope.where("leagues.name ILIKE ?", like)
      end

      def filter_by_status(scope)
        return scope unless status
        # Match any LeagueSeason the league owns whose status is the requested
        # value. When every League has at most one LeagueSeason in flight (the
        # current reality), this is equivalent to filtering by current LS.
        scope.where(id: LeagueSeason.where(status: status).select(:league_id))
      end

      def filter_by_users(scope)
        case users
        when "yes"
          scope.where(id: Participant.where.not(user_id: nil)
            .joins(:league_season).select("league_seasons.league_id"))
        when "no"
          scope.where.not(id: Participant.where.not(user_id: nil)
            .joins(:league_season).select("league_seasons.league_id"))
        else
          scope
        end
      end
    end
  end
end
