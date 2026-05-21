# frozen_string_literal: true

class User < ApplicationRecord
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participants, dependent: :nullify
  has_many :team_rankings, class_name: "UserTeamRanking", dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true,
    uniqueness: {case_sensitive: false},
    format: {with: EMAIL_FORMAT}
  validates :password, length: {minimum: 8}, allow_nil: true

  scope :active, -> { where(disabled_at: nil) }
  scope :disabled, -> { where.not(disabled_at: nil) }

  def disabled?
    disabled_at.present?
  end
end
