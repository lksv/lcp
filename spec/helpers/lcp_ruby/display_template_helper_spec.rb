require "spec_helper"

RSpec.describe LcpRuby::DisplayTemplateHelper, type: :helper do
  include described_class
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::OutputSafetyHelper

  let(:model_definition) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "contact",
      "fields" => [
        { "name" => "first_name", "type" => "string" },
        { "name" => "last_name", "type" => "string" },
        { "name" => "position", "type" => "string" },
        { "name" => "active", "type" => "boolean" }
      ],
      "associations" => [
        { "type" => "belongs_to", "name" => "company", "target_model" => "company", "foreign_key" => "company_id" }
      ],
      "display_templates" => {
        "default" => {
          "template" => "{first_name} {last_name}",
          "subtitle" => "{position}",
          "icon" => "user",
          "badge" => "{active}"
        },
        "compact" => {
          "template" => "{last_name}, {first_name}"
        },
        "card" => {
          "renderer" => "TestContactRenderer"
        },
        "mini" => {
          "partial" => "contacts/mini_label"
        }
      }
    )
  end

  let(:model_no_templates) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "simple",
      "fields" => [ { "name" => "name", "type" => "string" } ]
    )
  end

  let(:record) do
    double("contact",
      id: 1,
      first_name: "Alice",
      last_name: "Smith",
      position: "Engineer",
      active: true,
      to_label: "Alice Smith",
      to_s: "Alice Smith"
    )
  end

  let(:permission_evaluator) do
    instance_double(LcpRuby::Authorization::PermissionEvaluator,
      user: double("user"),
      field_readable?: true
    )
  end

  # Stub the FieldValueResolver to return template-interpolated values
  let(:field_resolver) do
    instance_double(LcpRuby::Presenter::FieldValueResolver)
  end

  before do
    allow(LcpRuby::Presenter::FieldValueResolver).to receive(:new).and_return(field_resolver)
    allow(field_resolver).to receive(:resolve) do |rec, template|
      template.to_s.gsub(/\{([^}]+)\}/) do
        field = Regexp.last_match(1).strip
        rec.respond_to?(field) ? rec.public_send(field).to_s : ""
      end
    end
  end

  describe "#render_display_template" do
    context "with structured template" do
      it "renders title from template" do
        result = render_display_template(record, model_definition,
          template_name: "default", permission_evaluator: permission_evaluator)

        expect(result).to include("Alice Smith")
        expect(result).to include("lcp-display-template__title")
      end

      it "renders subtitle" do
        result = render_display_template(record, model_definition,
          template_name: "default", permission_evaluator: permission_evaluator)

        expect(result).to include("Engineer")
        expect(result).to include("lcp-display-template__subtitle")
      end

      it "renders icon" do
        result = render_display_template(record, model_definition,
          template_name: "default", permission_evaluator: permission_evaluator)

        expect(result).to include("lcp-display-template__icon")
        expect(result).to include("user")
      end

      it "renders badge" do
        result = render_display_template(record, model_definition,
          template_name: "default", permission_evaluator: permission_evaluator)

        expect(result).to include("lcp-display-template__badge")
        expect(result).to include("true")
      end

      it "renders compact template without subtitle/icon/badge" do
        result = render_display_template(record, model_definition,
          template_name: "compact", permission_evaluator: permission_evaluator)

        expect(result).to include("Smith, Alice")
        expect(result).to include("lcp-display-template__title")
        expect(result).not_to include("lcp-display-template__subtitle")
        expect(result).not_to include("lcp-display-template__icon")
        expect(result).not_to include("lcp-display-template__badge")
      end

      it "wraps in container div with lcp-display-template class" do
        result = render_display_template(record, model_definition,
          template_name: "default", permission_evaluator: permission_evaluator)

        expect(result).to include('class="lcp-display-template"')
      end
    end

    context "with renderer template" do
      it "delegates to registered renderer" do
        renderer = double("renderer")
        allow(LcpRuby::Display::RendererRegistry).to receive(:renderer_for)
          .with("TestContactRenderer").and_return(renderer)
        allow(renderer).to receive(:render).and_return("<span>Custom</span>".html_safe)

        result = render_display_template(record, model_definition,
          template_name: "card", permission_evaluator: permission_evaluator)

        expect(result).to include("Custom")
      end

      it "falls back to to_label when renderer not found" do
        allow(LcpRuby::Display::RendererRegistry).to receive(:renderer_for)
          .with("TestContactRenderer").and_return(nil)

        result = render_display_template(record, model_definition,
          template_name: "card", permission_evaluator: permission_evaluator)

        expect(result).to include("Alice Smith")
      end
    end

    context "without display template (fallback)" do
      it "falls back to escaped to_label when no template defined" do
        result = render_display_template(record, model_no_templates,
          template_name: "default", permission_evaluator: permission_evaluator)

        expect(result).to eq("Alice Smith")
      end

      it "falls back to to_label for unknown template name" do
        result = render_display_template(record, model_definition,
          template_name: "nonexistent", permission_evaluator: permission_evaluator)

        expect(result).to eq("Alice Smith")
      end
    end

    context "with nil record" do
      it "returns empty string" do
        result = render_display_template(nil, model_definition,
          template_name: "default", permission_evaluator: permission_evaluator)

        expect(result).to eq("")
      end
    end

    context "without permission_evaluator" do
      it "renders template without field resolution" do
        result = render_display_template(record, model_definition,
          template_name: "compact", permission_evaluator: nil)

        # Without evaluator, template string is used as-is (no interpolation)
        expect(result).to include("lcp-display-template")
      end
    end
  end
end
