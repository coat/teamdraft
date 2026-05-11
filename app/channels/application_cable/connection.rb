# frozen_string_literal: true

module ApplicationCable
  # Anonymous Action Cable connections are allowed (cookie-only participants
  # need broadcasts too). When a user is signed in, identify them so we can
  # restrict streams later if needed.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user
    end

    private

    def find_user
      session = Session.find_by(id: cookies.signed[:session_id])
      session&.user
    end
  end
end
