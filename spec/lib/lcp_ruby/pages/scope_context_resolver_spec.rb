require "spec_helper"

RSpec.describe LcpRuby::Pages::ScopeContextResolver do
  let(:record) { OpenStruct.new(id: 42, department_id: 7, name: "Alice") }
  let(:user) { OpenStruct.new(id: 99, name: "Admin") }

  describe "#resolve" do
    it "resolves :record_id to the record's id" do
      resolver = described_class.new({ "employee_id" => ":record_id" }, record: record, user: user)
      expect(resolver.resolve).to eq("employee_id" => 42)
    end

    it "resolves :record.<field> via dot path" do
      resolver = described_class.new({ "dept_id" => ":record.department_id" }, record: record, user: user)
      expect(resolver.resolve).to eq("dept_id" => 7)
    end

    it "resolves :current_user_id to the user's id" do
      resolver = described_class.new({ "user_id" => ":current_user_id" }, record: record, user: user)
      expect(resolver.resolve).to eq("user_id" => 99)
    end

    it "resolves :current_year to the current year" do
      resolver = described_class.new({ "year" => ":current_year" }, record: record, user: user)
      expect(resolver.resolve).to eq("year" => Date.current.year)
    end

    it "resolves :current_date to today's date" do
      resolver = described_class.new({ "date" => ":current_date" }, record: record, user: user)
      expect(resolver.resolve).to eq("date" => Date.current)
    end

    it "passes static values through unchanged" do
      resolver = described_class.new({ "status" => "active", "count" => 5 }, record: record, user: user)
      expect(resolver.resolve).to eq("status" => "active", "count" => 5)
    end

    it "returns nil for record refs when record is nil" do
      resolver = described_class.new({ "employee_id" => ":record_id" }, record: nil, user: user)
      expect(resolver.resolve).to eq("employee_id" => nil)
    end

    it "returns nil for record dot-path when method does not exist" do
      resolver = described_class.new({ "val" => ":record.nonexistent" }, record: record, user: user)
      expect(resolver.resolve).to eq("val" => nil)
    end

    it "raises MetadataError for unknown reference" do
      resolver = described_class.new({ "val" => ":unknown_ref" }, record: record, user: user)
      expect { resolver.resolve }.to raise_error(LcpRuby::MetadataError, /Unknown scope_context reference/)
    end

    it "returns empty hash for nil scope_context" do
      resolver = described_class.new(nil, record: record, user: user)
      expect(resolver.resolve).to eq({})
    end

    it "returns empty hash for empty scope_context" do
      resolver = described_class.new({}, record: record, user: user)
      expect(resolver.resolve).to eq({})
    end

    it "resolves multiple values in scope_context" do
      scope_context = {
        "employee_id" => ":record_id",
        "year" => ":current_year",
        "status" => "pending"
      }
      resolver = described_class.new(scope_context, record: record, user: user)
      result = resolver.resolve
      expect(result["employee_id"]).to eq(42)
      expect(result["year"]).to eq(Date.current.year)
      expect(result["status"]).to eq("pending")
    end

    it "resolves :current_user to the full user object" do
      resolver = described_class.new({ "user" => ":current_user" }, record: record, user: user)
      expect(resolver.resolve).to eq("user" => user)
    end

    it "resolves :current_user to nil when user is nil" do
      resolver = described_class.new({ "user" => ":current_user" }, record: record, user: nil)
      expect(resolver.resolve).to eq("user" => nil)
    end

    it "raises MetadataError when dot-path exceeds maximum depth" do
      resolver = described_class.new(
        { "val" => ":record.department.company_id" },
        record: record,
        user: user
      )
      expect { resolver.resolve }.to raise_error(
        LcpRuby::MetadataError, /exceeds maximum depth of 1/
      )
    end

    it "allows single-level dot-path" do
      resolver = described_class.new({ "val" => ":record.department_id" }, record: record, user: user)
      expect(resolver.resolve).to eq("val" => 7)
    end
  end
end
