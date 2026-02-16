require "spec_helper"

RSpec.describe LcpRuby::Types::TypeRegistry do
  let(:type_def) do
    LcpRuby::Types::TypeDefinition.from_hash(
      "name" => "email",
      "base_type" => "string"
    )
  end

  describe ".register and .resolve" do
    it "registers and resolves a type definition" do
      described_class.register("email", type_def)
      expect(described_class.resolve("email")).to eq(type_def)
    end

    it "returns nil for unregistered type" do
      expect(described_class.resolve("nonexistent")).to be_nil
    end
  end

  describe ".registered?" do
    it "returns true for a registered type" do
      described_class.register("email", type_def)
      expect(described_class.registered?("email")).to be true
    end

    it "returns false for an unregistered type" do
      expect(described_class.registered?("unknown")).to be false
    end
  end

  describe ".clear!" do
    it "removes all registered types" do
      described_class.register("email", type_def)
      described_class.clear!
      expect(described_class.registered?("email")).to be false
    end
  end

  describe "built-in types after registration" do
    before do
      LcpRuby::Types::BuiltInTypes.register_all!
    end

    %w[email phone url color].each do |type_name|
      it "has '#{type_name}' registered" do
        expect(described_class.registered?(type_name)).to be true
      end

      it "resolves '#{type_name}' to a TypeDefinition" do
        resolved = described_class.resolve(type_name)
        expect(resolved).to be_a(LcpRuby::Types::TypeDefinition)
        expect(resolved.name).to eq(type_name)
      end
    end
  end
end
