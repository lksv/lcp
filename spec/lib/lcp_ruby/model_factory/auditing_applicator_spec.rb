require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::AuditingApplicator do
  let(:model_class) { Class.new(ActiveRecord::Base) }

  describe "#apply!" do
    context "when auditing is disabled" do
      it "does nothing" do
        model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "plain",
          "fields" => [ { "name" => "name", "type" => "string" } ],
          "options" => { "timestamps" => true }
        })

        expect {
          described_class.new(model_class, model_def).apply!
        }.not_to change { model_class.instance_methods(false).size }
      end
    end

    context "when auditing is enabled" do
      let(:model_def) do
        LcpRuby::Metadata::ModelDefinition.from_hash({
          "name" => "audited",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "options" => { "timestamps" => true, "auditing" => true }
        })
      end

      before do
        described_class.new(model_class, model_def).apply!
      end

      it "installs after_create callback" do
        callbacks = model_class._create_callbacks.map(&:kind)
        expect(callbacks).to include(:after)
      end

      it "installs after_update callback" do
        callbacks = model_class._update_callbacks.map(&:kind)
        expect(callbacks).to include(:after)
      end

      it "installs after_destroy callback" do
        callbacks = model_class._destroy_callbacks.map(&:kind)
        expect(callbacks).to include(:after)
      end

      it "adds audit_logs instance method" do
        expect(model_class.method_defined?(:audit_logs)).to be true
      end

      it "adds audit_history instance method" do
        expect(model_class.method_defined?(:audit_history)).to be true
      end
    end
  end
end
