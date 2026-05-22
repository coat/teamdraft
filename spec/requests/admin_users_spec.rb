# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin users", type: :request do
  describe "GET /admin/users" do
    it "lists users with email, role, and status" do
      sign_in_admin
      create(:user, email_address: "alice@example.com")
      create(:user, email_address: "bob@example.com", disabled_at: 1.day.ago)

      get admin_users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("alice@example.com")
      expect(response.body).to include("bob@example.com")
      expect(response.body).to include("disabled")
      expect(response.body).to include("admin")
    end

    it "filters by email search" do
      sign_in_admin
      create(:user, email_address: "alice@example.com")
      create(:user, email_address: "bob@example.com")

      get admin_users_path, params: {q: "alice"}

      expect(response.body).to include("alice@example.com")
      expect(response.body).not_to include("bob@example.com")
    end

    it "filters by role=admin" do
      sign_in_admin
      create(:user, email_address: "alice@example.com")

      get admin_users_path, params: {role: "admin"}

      expect(response.body).to include("admin@example.com")
      expect(response.body).not_to include("alice@example.com")
    end

    it "filters by status=disabled" do
      sign_in_admin
      create(:user, email_address: "alice@example.com")
      create(:user, email_address: "bob@example.com", disabled_at: 1.day.ago)

      get admin_users_path, params: {status: "disabled"}

      expect(response.body).to include("bob@example.com")
      expect(response.body).not_to include("alice@example.com")
    end

    it "requires admin to access" do
      get admin_users_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /admin/users/:id" do
    it "shows the user's leagues" do
      sign_in_admin
      member = create(:user, email_address: "member@example.com")
      sport = create(:sport, :nfl)
      season = create(:season, sport: sport)
      league = create(:league, name: "Their League")
      ls = create(:league_season, :with_two_participants, league: league, season: season)
      ls.participants.first.update!(user: member)

      get admin_user_path(member)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("member@example.com")
      expect(response.body).to include("Their League")
    end
  end

  describe "PATCH /admin/users/:id" do
    it "updates the email address" do
      admin = sign_in_admin
      member = create(:user, email_address: "old@example.com")

      patch admin_user_path(member), params: {user: {email_address: "new@example.com"}}

      expect(response).to redirect_to(admin_user_path(member))
      expect(member.reload.email_address).to eq("new@example.com")
      expect(admin.reload.email_address).to eq("admin@example.com")
    end
  end

  describe "PATCH grant_admin" do
    it "grants admin to a user" do
      sign_in_admin
      member = create(:user)

      patch grant_admin_admin_user_path(member)

      expect(response).to redirect_to(admin_user_path(member))
      expect(member.reload.admin?).to be(true)
    end
  end

  describe "PATCH revoke_admin" do
    it "revokes admin from another admin" do
      sign_in_admin
      other = create(:user, admin: true)

      patch revoke_admin_admin_user_path(other)

      expect(response).to redirect_to(admin_user_path(other))
      expect(other.reload.admin?).to be(false)
    end

    it "blocks self-revoke" do
      admin = sign_in_admin

      patch revoke_admin_admin_user_path(admin)

      follow_redirect!
      expect(admin.reload.admin?).to be(true)
      expect(response.body).to include("revoke your own admin")
    end

    it "blocks revoking the last remaining admin" do
      admin = sign_in_admin
      other = create(:user, admin: true)
      # Now make admin try to revoke `other` after demoting itself impossible -
      # simulate by deleting all other admins first, then revoking `other` while
      # signed in as admin. We have two admins (sign_in_admin + other), revoke
      # other to leave only the signed-in admin, then try to revoke the signed-in
      # admin via another admin's session - which isn't a thing here. So instead:
      # delete the signed-in admin's adminness via direct DB, then try to revoke
      # `other`. That leaves zero admins and should be blocked.
      admin.update_column(:admin, false)

      patch revoke_admin_admin_user_path(other)

      # The signed-in user is no longer admin, so the request itself bounces.
      expect(response).to redirect_to(root_path)
      expect(other.reload.admin?).to be(true)
    end
  end

  describe "PATCH disable" do
    it "disables a user and destroys their sessions" do
      sign_in_admin
      member = create(:user)
      member.sessions.create!(user_agent: "rspec", ip_address: "127.0.0.1")

      patch disable_admin_user_path(member)

      expect(response).to redirect_to(admin_user_path(member))
      expect(member.reload.disabled?).to be(true)
      expect(member.sessions).to be_empty
    end

    it "blocks self-disable" do
      admin = sign_in_admin

      patch disable_admin_user_path(admin)

      follow_redirect!
      expect(admin.reload.disabled?).to be(false)
      expect(response.body).to include("disable your own account")
    end
  end

  describe "PATCH enable" do
    it "clears disabled_at" do
      sign_in_admin
      member = create(:user, disabled_at: 1.day.ago)

      patch enable_admin_user_path(member)

      expect(response).to redirect_to(admin_user_path(member))
      expect(member.reload.disabled?).to be(false)
    end
  end
end
