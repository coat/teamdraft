# frozen_string_literal: true

module Admin
  module Users
    # Filter/sort logic for /admin/users. Whitelists sort columns + directions
    # so unsanitized params can never reach SQL ORDER BY. Mirrors the shape of
    # Admin::Leagues::ListQuery so the view code reads the same way.
    class ListQuery
      SORTS = {
        "email_address" => "users.email_address",
        "created_at" => "users.created_at"
      }.freeze

      ROLE_FILTERS = %w[admin non_admin].freeze
      STATUS_FILTERS = %w[active disabled].freeze

      def initialize(params = {})
        @params = params || {}
      end

      attr_reader :params

      def relation
        scope = User.all
        scope = filter_by_email(scope)
        scope = filter_by_role(scope)
        scope = filter_by_status(scope)
        scope.order(Arel.sql("#{SORTS.fetch(sort_column)} #{sort_dir}"))
      end

      def search_term
        params[:q].to_s.strip.presence
      end

      def role
        value = params[:role].to_s.presence
        ROLE_FILTERS.include?(value) ? value : nil
      end

      def status
        value = params[:status].to_s.presence
        STATUS_FILTERS.include?(value) ? value : nil
      end

      def sort_column
        col = params[:sort].to_s
        SORTS.key?(col) ? col : "email_address"
      end

      def sort_dir
        (params[:dir].to_s == "desc") ? "desc" : "asc"
      end

      def to_url_params(overrides = {})
        {
          q: search_term,
          role: role,
          status: status,
          sort: sort_column,
          dir: sort_dir
        }.merge(overrides).compact_blank
      end

      private

      def filter_by_email(scope)
        return scope unless search_term
        like = "%#{ActiveRecord::Base.sanitize_sql_like(search_term)}%"
        scope.where("users.email_address ILIKE ?", like)
      end

      def filter_by_role(scope)
        case role
        when "admin" then scope.where(admin: true)
        when "non_admin" then scope.where(admin: false)
        else scope
        end
      end

      def filter_by_status(scope)
        case status
        when "active" then scope.where(disabled_at: nil)
        when "disabled" then scope.where.not(disabled_at: nil)
        else scope
        end
      end
    end
  end
end
