require "spec_helper"

RSpec.describe LcpRuby::CustomFields::Utils do
  describe ".safe_parse_json" do
    it "parses valid JSON" do
      result = described_class.safe_parse_json('{"key":"value"}')
      expect(result).to eq({ "key" => "value" })
    end

    it "returns fallback for blank input" do
      expect(described_class.safe_parse_json("")).to eq({})
      expect(described_class.safe_parse_json(nil)).to eq({})
    end

    it "uses custom fallback" do
      expect(described_class.safe_parse_json("", fallback: [])).to eq([])
    end

    it "raises JSON::ParserError in local environment for invalid JSON" do
      allow(Rails.env).to receive(:local?).and_return(true)

      expect { described_class.safe_parse_json("not json") }
        .to raise_error(JSON::ParserError)
    end

    it "returns fallback and logs in non-local environment for invalid JSON" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(Rails.logger).to receive(:error).with(/JSON parse failed/)

      result = described_class.safe_parse_json(
        "not json", context: "project#custom_data (id: 42)"
      )
      expect(result).to eq({})
    end

    it "includes context in log message" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(Rails.logger).to receive(:error)
        .with(a_string_including("project#custom_data (id: 42)"))

      described_class.safe_parse_json("bad", context: "project#custom_data (id: 42)")
    end
  end

  describe ".safe_to_decimal" do
    it "converts valid numeric strings" do
      expect(described_class.safe_to_decimal("42")).to eq(BigDecimal("42"))
      expect(described_class.safe_to_decimal("3.14")).to eq(BigDecimal("3.14"))
    end

    it "converts integers" do
      expect(described_class.safe_to_decimal(42)).to eq(BigDecimal("42"))
    end

    it "raises ArgumentError in local environment for non-numeric input" do
      allow(Rails.env).to receive(:local?).and_return(true)

      expect { described_class.safe_to_decimal("abc") }
        .to raise_error(ArgumentError)
    end

    it "returns nil and logs in non-local environment for non-numeric input" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(Rails.logger).to receive(:error).with(/invalid numeric value/)

      result = described_class.safe_to_decimal(
        "abc", context: "project.score (id: 7)"
      )
      expect(result).to be_nil
    end

    it "includes context in log message" do
      allow(Rails.env).to receive(:local?).and_return(false)

      expect(Rails.logger).to receive(:error)
        .with(a_string_including("project.score (id: 7)"))

      described_class.safe_to_decimal("xyz", context: "project.score (id: 7)")
    end
  end
end
