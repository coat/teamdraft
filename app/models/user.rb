# frozen_string_literal: true

class User < ApplicationRecord
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participants, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true,
    uniqueness: {case_sensitive: false},
    format: {with: EMAIL_FORMAT}
  validates :password, length: {minimum: 8}, allow_nil: true
end
