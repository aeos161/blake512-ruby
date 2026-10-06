# frozen_string_literal: true

RSpec.describe Aeos::Blake512 do
  describe "::VERSION" do
    it "identifies the Phase 1 gem version" do
      expect(Aeos::Blake512::VERSION).to eq("0.1.0")
    end
  end
end
