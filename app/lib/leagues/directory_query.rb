# frozen_string_literal: true

module Leagues
  # Builds the team-directory rows shown on the league page (and powers
  # the in-app sort + filter UI). Mirrors `Admin::Leagues::ListQuery` -
  # whitelisted sort columns + safe filters + a `to_url_params` helper
  # for round-tripping current state through links and forms.
  #
  # Lives outside ActiveRecord because the sort keys span both DB columns
  # (rank, name, division) and computed values (pick number, which lives
  # on the optional associated DraftPick). 32 teams per season is small
  # enough that an in-memory comparator is simpler than a left-join SQL.
  class DirectoryQuery
    Row = Data.define(:season_team, :team, :pick, :points, :events, :user_rank)

    SORTS = %w[rank name division pick points].freeze

    def initialize(league_season:, params: {}, user: nil)
      @league_season = league_season
      @params = params || {}
      @user = user
    end

    attr_reader :league_season, :params

    def rows
      filtered = apply_filters(load_rows)
      sorted = filtered.sort_by.with_index { |row, i| [sort_key(row), i] }
      # The points sort bakes direction into the key so picked rows always
      # stay above unpicked ones regardless of dir; reversing here would
      # flip that grouping.
      sorted.reverse! if sort_dir == "desc" && sort_column != "points"
      sorted
    end

    def status
      # Absent param → fall back to the per-phase default. Explicit empty
      # string (e.g. user picked "All teams" in the dropdown) is honored.
      return default_status unless params.key?(:status)
      value = params[:status].to_s
      return "" if value.empty?
      # "Available" is only meaningful while drafting; ignore it post-draft
      # so a URL carrying status=available from before the final pick
      # doesn't render an empty page.
      return value if value == "available" && drafting?
      return value if value.start_with?("p:") && participant_id_from(value)
      ""
    end

    def division
      value = params[:division].to_s
      value.presence || ""
    end

    def sort_column
      col = params[:sort].to_s
      SORTS.include?(col) ? col : default_sort
    end

    def sort_dir
      explicit = params[:dir].to_s
      return explicit if %w[asc desc].include?(explicit)
      default_dir
    end

    def to_url_params(overrides = {})
      {
        sort: sort_column,
        dir: sort_dir,
        status: status,
        division: division
      }.merge(overrides).compact_blank
    end

    def default_sort
      (drafting? && !any_scoring_events?) ? "rank" : "points"
    end

    # True if any team in this season already has scoring events. Used by
    # the draft UI to decide whether to surface a Points column and bias
    # the default sort toward points-desc - the migration-mid-season case
    # where drafters benefit from seeing actual performance so far.
    def any_scoring_events?
      return @any_scoring_events if defined?(@any_scoring_events)
      @any_scoring_events = ScoringEvent.joins(:season_team)
        .where(season_teams: {season_id: @league_season.season_id})
        .exists?
    end

    def default_dir
      (sort_column == "points") ? "desc" : "asc"
    end

    def default_status
      drafting? ? "available" : ""
    end

    # Status filter token for one participant (e.g. for the dropdown's
    # `<option value="p:42">Picked by Alice</option>`).
    def status_token_for(participant)
      "p:#{participant.id}"
    end

    private

    def drafting? = @league_season.status == "drafting"

    def load_rows
      picks_by_team = @league_season.draft_picks.includes(:participant).index_by(&:season_team_id)
      rules = Scoring::Rules.for_league_season(@league_season)
      user_ranks = user_rank_map
      @league_season.season.season_teams.includes(:team, :scoring_events).map do |st|
        events = st.scoring_events
        breakdown = events.group_by(&:event_type)
          .transform_values { |list| list.sum { |e| rules.points_for(e.event_type) } }
        Row.new(
          season_team: st,
          team: st.team,
          pick: picks_by_team[st.id],
          points: events.sum { |e| rules.points_for(e.event_type) },
          events: breakdown,
          user_rank: user_ranks[st.team_id]
        )
      end
    end

    def user_rank_map
      return {} unless @user
      @user.team_rankings
        .where(sport_id: @league_season.season.sport_id)
        .pluck(:team_id, :rank).to_h
    end

    def apply_filters(rows)
      rows = filter_by_status(rows)
      filter_by_division(rows)
    end

    def filter_by_status(rows)
      token = status
      return rows if token.blank?
      if token == "available"
        rows.reject { |r| r.pick }
      else
        pid = participant_id_from(token)
        rows.select { |r| r.pick && r.pick.participant_id == pid }
      end
    end

    def filter_by_division(rows)
      return rows if division.blank?
      rows.select { |r| division_label(r.team) == division }
    end

    def sort_key(row)
      case sort_column
      when "name"
        [row.team.name.downcase]
      when "division"
        [division_label(row.team).to_s, rank_for(row)]
      when "pick"
        # Picked rows ascend by pick_number; available rows trail.
        [row.pick ? 0 : 1, row.pick&.pick_number || Float::INFINITY, row.team.name.downcase]
      when "points"
        # Picked rows ahead of unpicked; direction is baked into the key
        # so the picked/unpicked grouping survives a desc flip. Tiebreak
        # by team rank so pre-scoring ties (and mid-season drafts before
        # any pick lands) read as the rank board.
        signed_points = (sort_dir == "desc") ? -row.points.to_i : row.points.to_i
        [row.pick ? 0 : 1, signed_points, rank_for(row), row.team.name.downcase]
      else # "rank"
        [rank_for(row), row.team.name.downcase]
      end
    end

    # Two-tier sort key so personal-ranked teams sort first (in personal
    # order), then anything else falls through to the global default - the
    # same precedence the auto-pick query uses.
    def rank_for(row)
      personal = row.user_rank || Float::INFINITY
      global = row.team.default_pick_rank || Float::INFINITY
      [personal, global]
    end

    def division_label(team)
      [team.conference, team.division].compact_blank.join(" ").presence
    end

    def participant_id_from(token)
      Integer(token.sub(/\Ap:/, ""), exception: false)
    end
  end
end
