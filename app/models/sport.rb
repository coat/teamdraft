# frozen_string_literal: true

class Sport < ApplicationRecord
  has_many :seasons, dependent: :restrict_with_exception
  has_many :teams, dependent: :restrict_with_exception
  has_many :scoring_rules, -> { ordered }, dependent: :destroy

  validates :key, presence: true, uniqueness: {case_sensitive: false}
  validates :name, presence: true
  validates :active, inclusion: {in: [true, false]}

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:display_order, :name) }
end
