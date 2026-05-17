# frozen_string_literal: true

module Admin
  module Teams
    class ListQuery
      SORTS = {
        "name" => "teams.name",
        "rank" => "teams.default_pick_rank"
      }.freeze

      def initialize(params = {})
        @params = params || {}
      end

      attr_reader :params

      def relation
        scope = Team.includes(:sport)
        scope = filter_by_sport(scope)
        scope = filter_by_name(scope)
        scope.order(Arel.sql("#{SORTS.fetch(sort_column)} #{sort_dir} NULLS LAST"))
      end

      def search_term
        @params[:q].to_s.strip.presence
      end

      def sport_id
        @params[:sport_id].to_s.presence
      end

      def sort_column
        col = @params[:sort].to_s
        SORTS.key?(col) ? col : "rank"
      end

      def sort_dir
        (@params[:dir].to_s == "desc") ? "desc" : "asc"
      end

      def to_url_params(overrides = {})
        {
          q: search_term,
          sport_id: sport_id,
          sort: sort_column,
          dir: sort_dir
        }.merge(overrides).compact_blank
      end

      private

      def filter_by_sport(scope)
        return scope unless sport_id
        scope.where(sport_id: sport_id)
      end

      def filter_by_name(scope)
        return scope unless search_term
        like = "%#{ActiveRecord::Base.sanitize_sql_like(search_term)}%"
        scope.where("teams.name ILIKE ?", like)
      end
    end
  end
end
