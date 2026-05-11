# frozen_string_literal: true

module Users
  # Creates a User and links any Participants whose claim tokens already
  # live in the visitor's cookie. That's the "save your seat" upgrade
  # flow — the freshly-signed-up user inherits the seats they were already
  # holding anonymously.
  class SignUp
    def self.call(...) = new(...).call

    def initialize(email_address:, password:, password_confirmation:, claim_tokens: [])
      @email_address = email_address
      @password = password
      @password_confirmation = password_confirmation
      @claim_tokens = Array(claim_tokens)
    end

    def call
      ApplicationRecord.transaction do
        user = User.create!(
          email_address: @email_address,
          password: @password,
          password_confirmation: @password_confirmation
        )
        link_existing_participants(user)
        user
      end
    end

    private

    def link_existing_participants(user)
      return if @claim_tokens.empty?
      Participant.where(claim_token: @claim_tokens).update_all(user_id: user.id)
    end
  end
end
