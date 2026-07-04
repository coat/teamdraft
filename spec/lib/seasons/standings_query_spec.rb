# frozen_string_literal: true

require "rails_helper"

RSpec.describe Seasons::StandingsQuery do
  def query(params = {})
    described_class.new(season: build(:season), params: params)
  end

  describe "#view" do
    it "defaults to standings" do
      expect(query.view).to eq("standings")
    end

    it "accepts division" do
      expect(query(view: "division").view).to eq("division")
    end

    it "falls back to standings for unknown values" do
      expect(query(view: "bogus").view).to eq("standings")
    end
  end

  describe "#to_url_params" do
    it "omits the default standings view" do
      expect(query.to_url_params).not_to have_key(:view)
    end

    it "carries the division view" do
      expect(query(view: "division").to_url_params[:view]).to eq("division")
    end

    it "drops the view when overridden to nil" do
      expect(query(view: "division").to_url_params(view: nil)).not_to have_key(:view)
    end
  end
end
