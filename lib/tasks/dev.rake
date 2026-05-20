# frozen_string_literal: true

namespace :dev do
  desc "Seed local-dev convenience data (admin user, etc.)"
  task bootstrap: :environment do
    abort "dev:bootstrap is dev/test only" unless Rails.env.local?

    email = ENV.fetch("DEV_ADMIN_EMAIL", "admin@example.com")
    password = ENV.fetch("DEV_ADMIN_PASSWORD", "password123")

    user = User.find_or_initialize_by(email_address: email)
    user.password = password if user.new_record?
    user.admin = true
    user.save!

    puts "[dev] Admin ready: #{user.email_address} (password: #{password})"
  end
end
