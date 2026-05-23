# frozen_string_literal: true

# A user's personal ranking of a team within a sport. Rows override
# teams.default_pick_rank during AutoPick for the owning user's seats.
# sport_id is denormalized from team.sport_id and pinned at validate-time
# so the DB-side (user_id, sport_id, rank) uniqueness stays meaningful.
class UserTeamRanking < ApplicationRecord
  include Positional

  belongs_to :user
  belongs_to :team
  belongs_to :sport

  acts_positional column: :rank, scope: [:user_id, :sport_id]

  before_validation :copy_sport_from_team
  after_destroy_commit :collapse_higher_ranks

  validates :rank, presence: true,
    numericality: {only_integer: true, greater_than: 0},
    uniqueness: {scope: [:user_id, :sport_id]}
  validates :team_id, uniqueness: {scope: :user_id}
  validate :sport_matches_team

  private

  def copy_sport_from_team
    self.sport_id ||= team&.sport_id
  end

  def sport_matches_team
    return if team.blank? || sport_id.blank?
    errors.add(:sport_id, "must match team's sport") if sport_id != team.sport_id
  end

  # Keep ranks contiguous after a row is removed. Runs after_commit so the
  # deleted row is already gone before the shift, sidestepping the deferred
  # unique-constraint dance the swap path needs.
  def collapse_higher_ranks
    self.class.where(user_id: user_id, sport_id: sport_id)
      .where("rank > ?", rank)
      .update_all("rank = rank - 1")
  end
end
