# frozen_string_literal: true

class Team < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  belongs_to :sport
  has_many :season_teams, dependent: :restrict_with_exception
  has_many :seasons, through: :season_teams

  validates :name, presence: true
  validates :abbreviation, presence: true,
    uniqueness: {scope: :sport_id, case_sensitive: false}
  validates :slug, presence: true,
    uniqueness: {scope: :sport_id, case_sensitive: false},
    format: {with: SLUG_FORMAT}
  validates :external_id, uniqueness: {scope: :sport_id, allow_nil: true}

  # The Positional concern can't be used here: (sport_id, default_pick_rank)
  # is a unique *index*, not a deferrable unique *constraint*, so we can't
  # swap with `SET CONSTRAINTS ALL DEFERRED`. Park one row at NULL (allowed
  # by the index's nullable column) while the other moves, then restore.
  def swap_default_pick_rank_with(other)
    self.class.transaction do
      a_rank = default_pick_rank
      b_rank = other.default_pick_rank
      update!(default_pick_rank: nil)
      other.update!(default_pick_rank: a_rank)
      update!(default_pick_rank: b_rank)
    end
    true
  end

  def move_pick_rank_up!
    swap_pick_rank_with_neighbour(:above)
  end

  def move_pick_rank_down!
    swap_pick_rank_with_neighbour(:below)
  end

  private

  def swap_pick_rank_with_neighbour(direction)
    return false if default_pick_rank.nil?
    neighbour = pick_rank_neighbour(direction)
    return false unless neighbour
    swap_default_pick_rank_with(neighbour)
  end

  def pick_rank_neighbour(direction)
    scope = self.class.where(sport_id: sport_id).where.not(id: id)
    if direction == :above
      scope.where(default_pick_rank: ...default_pick_rank)
        .order(default_pick_rank: :desc).first
    else
      scope.where(default_pick_rank: (default_pick_rank + 1)..)
        .order(default_pick_rank: :asc).first
    end
  end
end
