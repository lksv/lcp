require "spec_helper"

RSpec.describe LcpRuby::FormHelper, type: :helper do
  include described_class

  describe "#render_form_input" do
    let(:form) { double("form") }
    let(:field_def) { nil }

    before do
      allow(form).to receive(:text_field).and_return("<input type='text'>".html_safe)
      allow(form).to receive(:text_area).and_return("<textarea></textarea>".html_safe)
      allow(form).to receive(:number_field).and_return("<input type='number'>".html_safe)
      allow(form).to receive(:date_field).and_return("<input type='date'>".html_safe)
      allow(form).to receive(:datetime_local_field).and_return("<input type='datetime-local'>".html_safe)
      allow(form).to receive(:check_box).and_return("<input type='checkbox'>".html_safe)
      allow(form).to receive(:email_field).and_return("<input type='email'>".html_safe)
      allow(form).to receive(:telephone_field).and_return("<input type='tel'>".html_safe)
      allow(form).to receive(:url_field).and_return("<input type='url'>".html_safe)
      allow(form).to receive(:color_field).and_return("<input type='color'>".html_safe)
      allow(form).to receive(:range_field).and_return("<input type='range'>".html_safe)
      allow(form).to receive(:select).and_return("<select></select>".html_safe)
    end

    it "renders text input as textarea" do
      expect(form).to receive(:text_area)
      render_form_input(form, :notes, "text", {}, field_def)
    end

    it "renders number input" do
      expect(form).to receive(:number_field).with(:amount, hash_including(step: "any"))
      render_form_input(form, :amount, "number", {}, field_def)
    end

    it "renders number with custom min/max" do
      config = { "input_options" => { "min" => 0, "max" => 100, "step" => 5 } }
      expect(form).to receive(:number_field).with(:amount, hash_including(min: 0, max: 100, step: 5))
      render_form_input(form, :amount, "number", config, field_def)
    end

    it "renders date_picker" do
      expect(form).to receive(:date_field).with(:start_date)
      render_form_input(form, :start_date, "date_picker", {}, field_def)
    end

    it "renders datetime" do
      expect(form).to receive(:datetime_local_field).with(:scheduled_at)
      render_form_input(form, :scheduled_at, "datetime", {}, field_def)
    end

    it "renders boolean as checkbox" do
      expect(form).to receive(:check_box).with(:active)
      render_form_input(form, :active, "boolean", {}, field_def)
    end

    it "renders email field" do
      expect(form).to receive(:email_field)
      render_form_input(form, :email, "email", {}, field_def)
    end

    it "renders tel field" do
      expect(form).to receive(:telephone_field)
      render_form_input(form, :phone, "tel", {}, field_def)
    end

    it "renders url field" do
      expect(form).to receive(:url_field)
      render_form_input(form, :website, "url", {}, field_def)
    end

    it "renders color field" do
      expect(form).to receive(:color_field).with(:theme_color)
      render_form_input(form, :theme_color, "color", {}, field_def)
    end

    it "renders slider input" do
      config = { "input_options" => { "min" => 0, "max" => 100, "step" => 5, "show_value" => true } }
      expect(form).to receive(:range_field).with(:priority, hash_including(min: 0, max: 100, step: 5))
      result = render_form_input(form, :priority, "slider", config, field_def)
      expect(result).to include("lcp-slider-wrapper")
      expect(result).to include("lcp-slider-value")
    end

    it "renders toggle input" do
      expect(form).to receive(:check_box).with(:active, hash_including(class: "lcp-toggle-input"))
      result = render_form_input(form, :active, "toggle", {}, field_def)
      expect(result).to include("lcp-toggle")
    end

    it "renders rating input as select" do
      config = { "input_options" => { "max" => 5 } }
      expect(form).to receive(:select).with(:rating, (0..5).map { |i| [ i.to_s, i ] }, include_blank: false)
      render_form_input(form, :rating, "rating", config, field_def)
    end

    it "renders text with character counter when show_counter is true" do
      config = { "input_options" => { "max_length" => 500, "show_counter" => true } }
      result = render_form_input(form, :notes, "text", config, field_def)
      expect(result).to include("lcp-char-counter")
    end

    it "renders text without counter when show_counter is false" do
      config = { "input_options" => { "max_length" => 500 } }
      result = render_form_input(form, :notes, "text", config, field_def)
      expect(result).not_to include("lcp-char-counter")
    end

    it "renders rich_text_editor as textarea" do
      expect(form).to receive(:text_area)
      render_form_input(form, :description, "rich_text_editor", {}, field_def)
    end

    it "renders date input" do
      expect(form).to receive(:date_field).with(:birthday)
      render_form_input(form, :birthday, "date", {}, field_def)
    end

    context "with association_select" do
      let(:lcp_assoc) do
        double("association", lcp_model?: true, target_model: "contact")
      end

      let(:non_lcp_assoc) do
        double("association", lcp_model?: false, target_model: "user")
      end

      it "renders select for LCP model association" do
        target_class = double("target_class")
        record = double("record", to_label: "John", id: 1)
        allow(target_class).to receive(:all).and_return([record])
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        expect(form).to receive(:select).with(:contact_id, [["John", 1]], include_blank: "-- Select --")
        render_form_input(form, :contact_id, "association_select", { "association" => lcp_assoc }, field_def)
      end

      it "renders number field for non-LCP model association" do
        expect(form).to receive(:number_field).with(:user_id, placeholder: "ID")
        render_form_input(form, :user_id, "association_select", { "association" => non_lcp_assoc }, field_def)
      end

      it "renders number field when association is nil" do
        expect(form).to receive(:number_field).with(:ref_id, placeholder: "ID")
        render_form_input(form, :ref_id, "association_select", { "association" => nil }, field_def)
      end
    end

    it "falls back to text_field for unknown input type" do
      expect(form).to receive(:text_field)
      render_form_input(form, :custom, "unknown_type", {}, field_def)
    end

    context "with enum field" do
      let(:field_def) do
        double("field_def",
          enum?: true,
          enum_value_names: %w[active inactive],
          type_definition: nil,
          type: "enum")
      end

      it "renders select with enum values" do
        expect(form).to receive(:select).with(:status,
          [ [ "Active", "active" ], [ "Inactive", "inactive" ] ],
          include_blank: true)
        render_form_input(form, :status, "select", {}, field_def)
      end
    end
  end
end
