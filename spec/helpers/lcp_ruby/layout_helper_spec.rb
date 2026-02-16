require "spec_helper"

RSpec.describe LcpRuby::LayoutHelper, type: :helper do
  include described_class

  describe "#hidden_on_classes" do
    it "returns empty string for nil input" do
      expect(hidden_on_classes(nil)).to eq("")
    end

    it "returns empty string for empty hash" do
      expect(hidden_on_classes({})).to eq("")
    end

    it "returns empty string when hidden_on key is missing" do
      expect(hidden_on_classes({ "field" => "name" })).to eq("")
    end

    it "returns classes for array of breakpoints" do
      config = { "hidden_on" => %w[mobile tablet] }
      expect(hidden_on_classes(config)).to eq("lcp-hidden-mobile lcp-hidden-tablet")
    end

    it "returns class for single string breakpoint" do
      config = { "hidden_on" => "mobile" }
      expect(hidden_on_classes(config)).to eq("lcp-hidden-mobile")
    end

    it "handles single-element array" do
      config = { "hidden_on" => ["desktop"] }
      expect(hidden_on_classes(config)).to eq("lcp-hidden-desktop")
    end
  end
end
