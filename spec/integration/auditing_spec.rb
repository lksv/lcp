require "spec_helper"
require "support/integration_helper"

RSpec.describe "Auditing integration", type: :request do
  include IntegrationHelper

  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("auditing")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("auditing")
  end

  # spec_helper resets LcpRuby state before each test, so reload metadata each time.
  before(:each) do
    load_integration_metadata!("auditing")
    stub_current_user(role: [ "admin" ], id: 42)
    LcpRuby::Current.user = OpenStruct.new(id: 42, email: "test@example.com", name: "Test User", lcp_role: [ "admin" ])
    audit_class.delete_all
    audited_class.delete_all
    unaudited_class.delete_all
  end

  let(:audit_class) { LcpRuby.registry.model_for("audit_log") }
  let(:audited_class) { LcpRuby.registry.model_for("audited_item") }
  let(:unaudited_class) { LcpRuby.registry.model_for("unaudited_item") }

  describe "create" do
    it "writes an audit log entry with action 'create'" do
      record = audited_class.create!(title: "Test Item", amount: 100)

      entries = audit_class.where(auditable_type: "audited_item", auditable_id: record.id)
      expect(entries.count).to eq(1)

      entry = entries.first
      expect(entry.action).to eq("create")
      expect(entry.changes_data).to include("title" => [ nil, "Test Item" ])
      expect(entry.changes_data).to include("amount" => [ nil, 100 ])
    end

    it "records user information" do
      LcpRuby::Current.user = OpenStruct.new(id: 42, email: "test@example.com", name: "Test User", lcp_role: [ "admin" ])

      record = audited_class.create!(title: "Test")

      entry = audit_class.where(auditable_type: "audited_item", auditable_id: record.id).first
      expect(entry.user_id).to eq(42)
      expect(entry.user_snapshot).to include("id" => 42, "email" => "test@example.com")
    end
  end

  describe "update" do
    it "writes an audit log entry with only changed fields" do
      record = audited_class.create!(title: "Original", amount: 50)
      audit_class.delete_all # clear create entry

      record.update!(title: "Updated")

      entries = audit_class.where(auditable_type: "audited_item", auditable_id: record.id)
      expect(entries.count).to eq(1)

      entry = entries.first
      expect(entry.action).to eq("update")
      expect(entry.changes_data).to include("title" => [ "Original", "Updated" ])
      expect(entry.changes_data).not_to have_key("amount")
    end

    it "skips audit entry when no tracked fields change" do
      record = audited_class.create!(title: "Same")
      audit_class.delete_all

      # save without changes
      record.save!

      entries = audit_class.where(auditable_type: "audited_item", auditable_id: record.id)
      expect(entries.count).to eq(0)
    end
  end

  describe "destroy" do
    it "writes an audit log entry with all field values" do
      record = audited_class.create!(title: "To Delete", amount: 200)
      record_id = record.id
      audit_class.delete_all

      record.destroy!

      entries = audit_class.where(auditable_type: "audited_item", auditable_id: record_id)
      expect(entries.count).to eq(1)

      entry = entries.first
      expect(entry.action).to eq("destroy")
      expect(entry.changes_data).to include("title" => [ "To Delete", nil ])
      expect(entry.changes_data).to include("amount" => [ 200, nil ])
    end
  end

  describe "non-audited model" do
    it "does not create audit entries" do
      unaudited_class.create!(name: "No Audit")

      expect(audit_class.count).to eq(0)
    end
  end

  describe "audit_logs association" do
    it "returns audit entries for the record" do
      record = audited_class.create!(title: "Test")
      record.update!(title: "Updated")

      logs = record.audit_logs
      expect(logs.count).to eq(2)
      expect(logs.map(&:action)).to contain_exactly("create", "update")
    end
  end

  describe "audit_history convenience method" do
    it "returns limited audit entries" do
      record = audited_class.create!(title: "Test")
      record.update!(title: "Updated 1")
      record.update!(title: "Updated 2")

      history = record.audit_history(limit: 2)
      expect(history.count).to eq(2)
    end
  end

  describe "transaction safety" do
    it "rolls back audit entry when save fails" do
      initial_count = audit_class.count

      begin
        ActiveRecord::Base.transaction do
          audited_class.create!(title: "Will rollback")
          raise ActiveRecord::Rollback
        end
      rescue
        # expected
      end

      expect(audit_class.count).to eq(initial_count)
    end
  end

  describe "HTTP CRUD actions" do
    it "creates audit entry on POST create" do
      post "/audited-items", params: { record: { title: "Via HTTP", amount: 50 } }
      expect(response).to redirect_to(%r{/audited-items/\d+})

      expect(audit_class.count).to eq(1)
      entry = audit_class.last
      expect(entry.action).to eq("create")
      expect(entry.changes_data["title"]).to eq([ nil, "Via HTTP" ])
    end

    it "creates audit entry on PATCH update" do
      record = audited_class.create!(title: "Before")
      audit_class.delete_all

      patch "/audited-items/#{record.id}", params: { record: { title: "After" } }
      expect(response).to redirect_to(%r{/audited-items/\d+})

      expect(audit_class.count).to eq(1)
      entry = audit_class.last
      expect(entry.action).to eq("update")
      expect(entry.changes_data["title"]).to eq([ "Before", "After" ])
    end

    it "creates audit entry on DELETE destroy" do
      record = audited_class.create!(title: "To Delete")
      record_id = record.id
      audit_class.delete_all

      delete "/audited-items/#{record_id}"
      expect(response).to redirect_to("/audited-items")

      entries = audit_class.where(auditable_type: "audited_item", auditable_id: record_id)
      expect(entries.count).to eq(1)
      expect(entries.first.action).to eq("destroy")
    end

    it "does not create audit entry for unaudited model" do
      post "/unaudited-items", params: { record: { name: "No Audit" } }
      expect(audit_class.count).to eq(0)
    end
  end
end
