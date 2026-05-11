# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::Order do
  describe ".position_for" do
    context "snake, size 2" do
      it "produces the 1,2,2,1,1,2 sequence" do
        positions = (1..6).map { |n| Drafts::Order.position_for(pick_number: n, size: 2, style: "snake") }
        expect(positions).to eq([1, 2, 2, 1, 1, 2])
      end
    end

    context "linear, size 2" do
      it "alternates strictly" do
        positions = (1..6).map { |n| Drafts::Order.position_for(pick_number: n, size: 2, style: "linear") }
        expect(positions).to eq([1, 2, 1, 2, 1, 2])
      end
    end

    context "snake, size 3" do
      it "reverses each odd round" do
        positions = (1..9).map { |n| Drafts::Order.position_for(pick_number: n, size: 3, style: "snake") }
        expect(positions).to eq([1, 2, 3, 3, 2, 1, 1, 2, 3])
      end
    end

    it "rejects pick_number < 1" do
      expect { Drafts::Order.position_for(pick_number: 0, size: 2, style: "snake") }
        .to raise_error(ArgumentError)
    end

    it "rejects size < 2" do
      expect { Drafts::Order.position_for(pick_number: 1, size: 1, style: "snake") }
        .to raise_error(ArgumentError)
    end
  end
end
