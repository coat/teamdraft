# frozen_string_literal: true

class Sport < ApplicationRecord
  has_many :seasons, dependent: :restrict_with_exception
  has_many :teams, dependent: :restrict_with_exception

  validates :key, presence: true, uniqueness: {case_sensitive: false}
  validates :name, presence: true
  validates :active, inclusion: {in: [true, false]}
end
