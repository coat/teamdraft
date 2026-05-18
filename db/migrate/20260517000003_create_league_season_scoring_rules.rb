# frozen_string_literal: true

# Per-league_season copy of a sport's scoring_rules. Each LeagueSeason gets one
# row per sport ScoringRule, owning only the point value — labels, kind,
# round_key, and bye_backfill stay sport-controlled. Lets owners customize
# point values without forking ScoringEvents per league: Standings::Calculate
# resolves points through these overrides at read time.
class CreateLeagueSeasonScoringRules < ActiveRecord::Migration[8.1]
  def up
    create_table :league_season_scoring_rules do |t|
      t.references :league_season, null: false, foreign_key: {on_delete: :cascade}
      t.references :scoring_rule, null: false, foreign_key: {on_delete: :cascade}
      t.integer :points, null: false, default: 0
      t.timestamps
    end

    add_index :league_season_scoring_rules, [:league_season_id, :scoring_rule_id],
      unique: true, name: "idx_lssr_on_league_season_and_rule"

    add_check_constraint :league_season_scoring_rules,
      "points >= 0",
      name: "lssr_points_non_negative"

    backfill_existing_league_seasons
  end

  def down
    drop_table :league_season_scoring_rules
  end

  private

  # Seed one override row per sport ScoringRule for every existing LeagueSeason,
  # copying the sport's default points. Keeps standings identical the moment
  # Standings::Calculate switches to reading via these overrides.
  def backfill_existing_league_seasons
    league_season = Class.new(ActiveRecord::Base) { self.table_name = "league_seasons" }
    season = Class.new(ActiveRecord::Base) { self.table_name = "seasons" }
    rule = Class.new(ActiveRecord::Base) { self.table_name = "scoring_rules" }
    override = Class.new(ActiveRecord::Base) { self.table_name = "league_season_scoring_rules" }

    league_season.find_each do |ls|
      sport_id = season.where(id: ls.season_id).pick(:sport_id)
      next unless sport_id
      rule.where(sport_id: sport_id).each do |sr|
        override.create!(
          league_season_id: ls.id,
          scoring_rule_id: sr.id,
          points: sr.points
        )
      end
    end
  end
end
