# frozen_string_literal: true

namespace :admin do
  desc "Promote a user to admin: bin/rails 'admin:promote[email@example.com]'"
  task :promote, [:email] => :environment do |_, args|
    email = args[:email].to_s.strip.downcase
    abort "Usage: bin/rails 'admin:promote[email@example.com]'" if email.empty?

    user = User.find_by(email_address: email)
    abort "No user with email #{email}" unless user

    user.update!(admin: true)
    puts "[admin] Promoted #{user.email_address} (id=#{user.id})"
  end

  desc "Demote a user from admin: bin/rails 'admin:demote[email@example.com]'"
  task :demote, [:email] => :environment do |_, args|
    email = args[:email].to_s.strip.downcase
    abort "Usage: bin/rails 'admin:demote[email@example.com]'" if email.empty?

    user = User.find_by(email_address: email)
    abort "No user with email #{email}" unless user

    user.update!(admin: false)
    puts "[admin] Demoted #{user.email_address}"
  end
end
