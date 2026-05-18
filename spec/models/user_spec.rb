# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "#disabled?" do
    it "is false when disabled_at is nil" do
      user = create(:user)

      expect(user.disabled?).to be(false)
    end

    it "is true when disabled_at is set" do
      user = create(:user, disabled_at: Time.current)

      expect(user.disabled?).to be(true)
    end
  end

  describe "scopes" do
    it ".active returns only users without a disabled_at" do
      active = create(:user)
      create(:user, disabled_at: 1.hour.ago)

      expect(User.active).to contain_exactly(active)
    end

    it ".disabled returns only users with a disabled_at" do
      create(:user)
      disabled = create(:user, disabled_at: 1.hour.ago)

      expect(User.disabled).to contain_exactly(disabled)
    end
  end
end
