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
      allow(form).to receive(:object).and_return(nil)

      # build_options_query calls .limit() on queries; stub it for Array results
      allow_any_instance_of(Array).to receive(:limit) { |arr, _n| arr }
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

      before do
        # Default: resolve_default_label_method falls back to :to_label
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition)
          .and_raise(LcpRuby::MetadataError, "not found")
      end

      it "renders select for LCP model association" do
        target_class = double("target_class")
        record = double("record", to_label: "John", id: 1)
        allow(target_class).to receive(:all).and_return([ record ])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        expect(form).to receive(:select).with(:contact_id, [ [ "John", 1 ] ], { include_blank: "-- Select --" }, hash_including("data-lcp-search" => "local"))
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

      context "with scope" do
        it "applies named scope on target class" do
          target_class = double("target_class")
          scoped = double("scoped_query")
          record = double("record", to_label: "Active Co", id: 1)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(target_class).to receive(:respond_to?).with("active").and_return(true)
          allow(target_class).to receive(:send).with("active").and_return(scoped)
          allow(scoped).to receive(:where).and_return(scoped)
          allow(scoped).to receive(:order).and_return(scoped)
          allow(scoped).to receive(:limit).and_return(scoped)
          allow(scoped).to receive(:map).and_return([ [ "Active Co", 1 ] ])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = { "association" => lcp_assoc, "input_options" => { "scope" => "active" } }
          expect(form).to receive(:select)
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
      end

      context "with filter" do
        it "applies where conditions" do
          target_class = double("target_class")
          query = double("query")
          filtered = double("filtered")
          allow(target_class).to receive(:all).and_return(query)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(query).to receive(:where).with({ "industry" => "technology" }).and_return(filtered)
          allow(filtered).to receive(:limit).and_return(filtered)
          allow(filtered).to receive(:map).and_return([ [ "Tech Co", 1 ] ])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = { "association" => lcp_assoc, "input_options" => { "filter" => { "industry" => "technology" } } }
          expect(form).to receive(:select)
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
      end

      context "with sort" do
        it "applies order" do
          target_class = double("target_class")
          query = double("query")
          sorted = double("sorted")
          allow(target_class).to receive(:all).and_return(query)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(query).to receive(:order).with({ "name" => "asc" }).and_return(sorted)
          allow(sorted).to receive(:limit).and_return(sorted)
          allow(sorted).to receive(:map).and_return([ [ "Alpha", 1 ], [ "Beta", 2 ] ])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = { "association" => lcp_assoc, "input_options" => { "sort" => { "name" => "asc" } } }
          expect(form).to receive(:select)
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
      end

      context "with label_method" do
        it "uses custom label method" do
          target_class = double("target_class")
          record = double("record", full_name: "John Doe", id: 1)
          allow(record).to receive(:respond_to?).with(:full_name).and_return(true)
          allow(record).to receive(:send).with(:full_name).and_return("John Doe")
          allow(target_class).to receive(:all).and_return([ record ])
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = { "association" => lcp_assoc, "input_options" => { "label_method" => "full_name" } }
          expect(form).to receive(:select).with(:contact_id, [ [ "John Doe", 1 ] ], { include_blank: "-- Select --" }, hash_including("data-lcp-search" => "local"))
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "falls back to to_s when label method not available" do
          target_class = double("target_class")
          record = double("record", id: 1, to_s: "Record #1")
          allow(record).to receive(:respond_to?).with(:custom_label).and_return(false)
          allow(target_class).to receive(:all).and_return([ record ])
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = { "association" => lcp_assoc, "input_options" => { "label_method" => "custom_label" } }
          expect(form).to receive(:select).with(:contact_id, [ [ "Record #1", 1 ] ], { include_blank: "-- Select --" }, hash_including("data-lcp-search" => "local"))
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
      end

      context "with include_blank" do
        it "uses custom include_blank string" do
          target_class = double("target_class")
          allow(target_class).to receive(:all).and_return([])
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = { "association" => lcp_assoc, "input_options" => { "include_blank" => "-- Choose --" } }
          expect(form).to receive(:select).with(:contact_id, [], { include_blank: "-- Choose --" }, hash_including("data-lcp-search" => "local"))
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "disables blank option with include_blank: false" do
          target_class = double("target_class")
          allow(target_class).to receive(:all).and_return([])
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = { "association" => lcp_assoc, "input_options" => { "include_blank" => false } }
          expect(form).to receive(:select).with(:contact_id, [], { include_blank: false }, hash_including("data-lcp-search" => "local"))
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
      end

      context "with group_by" do
        it "renders grouped options" do
          target_class = double("target_class")
          tech_record = double("tech_record", id: 1, industry: "technology")
          fin_record = double("fin_record", id: 2, industry: "finance")
          allow(tech_record).to receive(:respond_to?).with(:to_label).and_return(true)
          allow(tech_record).to receive(:send).with(:to_label).and_return("TechCo")
          allow(tech_record).to receive(:send).with("industry").and_return("technology")
          allow(fin_record).to receive(:respond_to?).with(:to_label).and_return(true)
          allow(fin_record).to receive(:send).with(:to_label).and_return("FinCo")
          allow(fin_record).to receive(:send).with("industry").and_return("finance")

          query = [ tech_record, fin_record ]
          allow(target_class).to receive(:all).and_return(query)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(query).to receive(:group_by).and_return({
            "technology" => [ tech_record ],
            "finance" => [ fin_record ]
          })
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          obj = double("obj")
          allow(obj).to receive(:send).with(:contact_id).and_return(nil)
          allow(form).to receive(:object).and_return(obj)

          config = { "association" => lcp_assoc, "input_options" => { "group_by" => "industry" } }
          expect(self).to receive(:grouped_options_for_select).and_return("<options>".html_safe)
          expect(form).to receive(:select)
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
      end

      context "with depends_on" do
        it "renders data attributes for dependent select" do
          target_class = double("target_class")
          allow(target_class).to receive(:all).and_return([])
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = {
            "association" => lcp_assoc,
            "input_options" => {
              "depends_on" => { "field" => "company_id", "foreign_key" => "company_id" }
            }
          }
          expect(form).to receive(:select).with(
            :contact_id, [],
            { include_blank: "-- Select --" },
            hash_including(
              "data-lcp-depends-on" => "company_id",
              "data-lcp-depends-fk" => "company_id",
              "data-lcp-depends-reset" => "clear"
            )
          )
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "uses custom reset_strategy" do
          target_class = double("target_class")
          allow(target_class).to receive(:all).and_return([])
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = {
            "association" => lcp_assoc,
            "input_options" => {
              "depends_on" => {
                "field" => "company_id",
                "foreign_key" => "company_id",
                "reset_strategy" => "keep_if_valid"
              }
            }
          }
          expect(form).to receive(:select).with(
            :contact_id, [],
            { include_blank: "-- Select --" },
            hash_including("data-lcp-depends-reset" => "keep_if_valid")
          )
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "filters by parent value when record has depends_on parent set" do
          target_class = double("target_class")
          all_query = double("all_query")
          filtered_query = double("filtered_query")
          record_obj = double("record", company_id: 5)

          allow(target_class).to receive(:all).and_return(all_query)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(all_query).to receive(:where).with("company_id" => 5).and_return(filtered_query)
          allow(filtered_query).to receive(:limit).and_return(filtered_query)
          allow(filtered_query).to receive(:map).and_return([ [ "John Doe", 10 ] ])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)
          allow(record_obj).to receive(:respond_to?).with("company_id").and_return(true)

          config = {
            "association" => lcp_assoc,
            "input_options" => {
              "depends_on" => { "field" => "company_id", "foreign_key" => "company_id" }
            }
          }
          allow(form).to receive(:object).and_return(record_obj)
          expect(form).to receive(:select).with(
            :contact_id, [ [ "John Doe", 10 ] ],
            { include_blank: "-- Select --" },
            hash_including("data-lcp-depends-on" => "company_id")
          )
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "returns all options when record has nil parent value" do
          target_class = double("target_class")
          all_query = double("all_query")
          record_obj = double("record", company_id: nil)

          allow(target_class).to receive(:all).and_return(all_query)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(all_query).to receive(:limit).and_return(all_query)
          allow(all_query).to receive(:map).and_return([ [ "John Doe", 10 ], [ "Jane Smith", 11 ] ])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)
          allow(record_obj).to receive(:respond_to?).with("company_id").and_return(true)

          config = {
            "association" => lcp_assoc,
            "input_options" => {
              "depends_on" => { "field" => "company_id", "foreign_key" => "company_id" }
            }
          }
          allow(form).to receive(:object).and_return(record_obj)
          expect(form).to receive(:select).with(
            :contact_id, [ [ "John Doe", 10 ], [ "Jane Smith", 11 ] ],
            { include_blank: "-- Select --" },
            hash_including("data-lcp-depends-on" => "company_id")
          )
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "returns all options for new record (no parent value)" do
          target_class = double("target_class")
          all_query = double("all_query")

          allow(target_class).to receive(:all).and_return(all_query)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(all_query).to receive(:limit).and_return(all_query)
          allow(all_query).to receive(:map).and_return([ [ "John", 10 ] ])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = {
            "association" => lcp_assoc,
            "input_options" => {
              "depends_on" => { "field" => "company_id", "foreign_key" => "company_id" }
            }
          }
          expect(form).to receive(:select).with(
            :contact_id, [ [ "John", 10 ] ],
            { include_blank: "-- Select --" },
            hash_including("data-lcp-depends-on" => "company_id")
          )
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
      end

      context "with scope_by_role" do
        before do
          user = double("user", lcp_role: "editor")
          allow(LcpRuby::Current).to receive(:user).and_return(user)
        end

        it "applies scope matching current user role" do
          target_class = double("target_class")
          scoped = double("scoped")
          record = double("record", to_label: "Active Co", id: 1)
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(target_class).to receive(:respond_to?).with("active_companies").and_return(true)
          allow(target_class).to receive(:send).with("active_companies").and_return(scoped)
          allow(scoped).to receive(:limit).and_return(scoped)
          allow(scoped).to receive(:map).and_return([ [ "Active Co", 1 ] ])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = {
            "association" => lcp_assoc,
            "input_options" => {
              "scope_by_role" => { "editor" => "active_companies", "admin" => "all" }
            }
          }
          expect(form).to receive(:select)
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "returns unscoped for role with 'all' scope" do
          user = double("user", lcp_role: "admin")
          allow(LcpRuby::Current).to receive(:user).and_return(user)

          target_class = double("target_class")
          all_query = double("all_query")
          allow(target_class).to receive(:all).and_return(all_query)
          allow(all_query).to receive(:limit).and_return(all_query)
          allow(all_query).to receive(:map).and_return([])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = {
            "association" => lcp_assoc,
            "input_options" => {
              "scope_by_role" => { "admin" => "all" }
            }
          }
          expect(form).to receive(:select)
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end

        it "falls back to scope when scope_by_role not set" do
          target_class = double("target_class")
          scoped = double("scoped")
          allow(target_class).to receive(:all).and_return(double("all"))
          allow(target_class).to receive(:respond_to?).and_return(false)
          allow(target_class).to receive(:respond_to?).with("active").and_return(true)
          allow(target_class).to receive(:send).with("active").and_return(scoped)
          allow(scoped).to receive(:limit).and_return(scoped)
          allow(scoped).to receive(:map).and_return([])
          allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

          config = {
            "association" => lcp_assoc,
            "input_options" => { "scope" => "active" }
          }
          expect(form).to receive(:select)
          render_form_input(form, :contact_id, "association_select", config, field_def)
        end
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

      it "renders select with include_blank: false" do
        config = { "input_options" => { "include_blank" => false } }
        expect(form).to receive(:select).with(:status,
          [ [ "Active", "active" ], [ "Inactive", "inactive" ] ],
          include_blank: false)
        render_form_input(form, :status, "select", config, field_def)
      end

      context "with role-based include_values" do
        let(:field_def) do
          double("field_def",
            enum?: true,
            enum_value_names: %w[active inactive deleted],
            type_definition: nil,
            type: "enum")
        end

        before do
          user = double("user", lcp_role: "viewer")
          allow(LcpRuby::Current).to receive(:user).and_return(user)
        end

        it "whitelists values for matching role" do
          config = {
            "input_options" => {
              "include_values" => { "viewer" => %w[active inactive] }
            }
          }
          expect(form).to receive(:select).with(:status,
            [ [ "Active", "active" ], [ "Inactive", "inactive" ] ],
            include_blank: true)
          render_form_input(form, :status, "select", config, field_def)
        end
      end

      context "with role-based exclude_values" do
        let(:field_def) do
          double("field_def",
            enum?: true,
            enum_value_names: %w[active inactive deleted],
            type_definition: nil,
            type: "enum")
        end

        before do
          user = double("user", lcp_role: "editor")
          allow(LcpRuby::Current).to receive(:user).and_return(user)
        end

        it "excludes values for matching role" do
          config = {
            "input_options" => {
              "exclude_values" => { "editor" => %w[deleted] }
            }
          }
          expect(form).to receive(:select).with(:status,
            [ [ "Active", "active" ], [ "Inactive", "inactive" ] ],
            include_blank: true)
          render_form_input(form, :status, "select", config, field_def)
        end
      end

      context "with both include_values and exclude_values" do
        let(:field_def) do
          double("field_def",
            enum?: true,
            enum_value_names: %w[lead qualified proposal closed_won closed_lost],
            type_definition: nil,
            type: "enum")
        end

        before do
          user = double("user", lcp_role: "sales")
          allow(LcpRuby::Current).to receive(:user).and_return(user)
        end

        it "applies include first, then exclude" do
          config = {
            "input_options" => {
              "include_values" => { "sales" => %w[lead qualified proposal] },
              "exclude_values" => { "sales" => %w[lead] }
            }
          }
          expect(form).to receive(:select).with(:status,
            [ [ "Qualified", "qualified" ], [ "Proposal", "proposal" ] ],
            include_blank: true)
          render_form_input(form, :status, "select", config, field_def)
        end
      end

      context "with non-matching role" do
        let(:field_def) do
          double("field_def",
            enum?: true,
            enum_value_names: %w[active inactive deleted],
            type_definition: nil,
            type: "enum")
        end

        before do
          user = double("user", lcp_role: "admin")
          allow(LcpRuby::Current).to receive(:user).and_return(user)
        end

        it "returns all values when role does not match any filter" do
          config = {
            "input_options" => {
              "exclude_values" => { "viewer" => %w[deleted] }
            }
          }
          expect(form).to receive(:select).with(:status,
            [ [ "Active", "active" ], [ "Inactive", "inactive" ], [ "Deleted", "deleted" ] ],
            include_blank: true)
          render_form_input(form, :status, "select", config, field_def)
        end
      end
    end

    context "with multi_select" do
      let(:through_assoc) do
        double("through_assoc", lcp_model?: true, target_model: "tag", through?: true)
      end

      before do
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition)
          .and_raise(LcpRuby::MetadataError, "not found")
      end

      it "renders select with multiple attribute" do
        target_class = double("target_class")
        record = double("record", to_label: "Ruby", id: 1)
        allow(record).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(record).to receive(:send).with(:to_label).and_return("Ruby")
        allow(target_class).to receive(:all).and_return([ record ])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("tag").and_return(target_class)

        config = {
          "multi_select_association" => through_assoc,
          "input_options" => {}
        }
        expect(form).to receive(:select).with(
          :tag_ids, [ [ "Ruby", 1 ] ],
          { include_blank: false },
          hash_including(multiple: true)
        )
        render_form_input(form, :tag_ids, "multi_select", config, field_def)
      end

      it "renders with min/max data attributes" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("tag").and_return(target_class)

        config = {
          "multi_select_association" => through_assoc,
          "input_options" => { "min" => 1, "max" => 5 }
        }
        expect(form).to receive(:select).with(
          :tag_ids, [],
          { include_blank: false },
          hash_including(multiple: true, "data-min": 1, "data-max": 5)
        )
        render_form_input(form, :tag_ids, "multi_select", config, field_def)
      end

      it "renders with display_mode data attribute" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("tag").and_return(target_class)

        config = {
          "multi_select_association" => through_assoc,
          "input_options" => { "display_mode" => "single_line" }
        }
        expect(form).to receive(:select).with(
          :tag_ids, [],
          { include_blank: false },
          hash_including(multiple: true, "data-lcp-display-mode" => "single_line")
        )
        render_form_input(form, :tag_ids, "multi_select", config, field_def)
      end

      it "does not add display_mode attribute when not configured" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("tag").and_return(target_class)

        config = {
          "multi_select_association" => through_assoc,
          "input_options" => {}
        }
        expect(form).to receive(:select).with(
          :tag_ids, [],
          { include_blank: false },
          hash_not_including("data-lcp-display-mode")
        )
        render_form_input(form, :tag_ids, "multi_select", config, field_def)
      end

      it "renders text_field when association is nil" do
        config = { "multi_select_association" => nil, "input_options" => {} }
        expect(form).to receive(:text_field).with(:tag_ids)
        render_form_input(form, :tag_ids, "multi_select", config, field_def)
      end

      it "applies scope and sort" do
        target_class = double("target_class")
        scoped = double("scoped")
        sorted = double("sorted")
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with("active").and_return(true)
        allow(target_class).to receive(:send).with("active").and_return(scoped)
        allow(scoped).to receive(:order).with({ "name" => "asc" }).and_return(sorted)
        allow(sorted).to receive(:limit).and_return(sorted)
        allow(sorted).to receive(:map).and_return([ [ "Active Tag", 1 ] ])
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("tag").and_return(target_class)

        config = {
          "multi_select_association" => through_assoc,
          "input_options" => { "scope" => "active", "sort" => { "name" => "asc" } }
        }
        expect(form).to receive(:select)
        render_form_input(form, :tag_ids, "multi_select", config, field_def)
      end
    end

    context "selective column loading" do
      let(:lcp_assoc) do
        double("association", lcp_model?: true, target_model: "contact")
      end

      it "applies select(:id, label_col) when model metadata label_method is a DB column" do
        target_class = double("target_class")
        all_query = double("all_query")
        selected_query = double("selected_query")

        allow(target_class).to receive(:all).and_return(all_query)
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with(:column_names).and_return(true)
        allow(target_class).to receive(:column_names).and_return(%w[id name email])
        allow(all_query).to receive(:select).with(:id, :name).and_return(selected_query)
        allow(selected_query).to receive(:limit).and_return(selected_query)
        allow(selected_query).to receive(:map).and_return([ [ "Acme", 1 ] ])
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        model_def = double("model_def", label_method: "name")
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition).with("contact").and_return(model_def)

        config = { "association" => lcp_assoc, "input_options" => {} }
        expect(form).to receive(:select)
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "applies select(:id, label_col) when explicit label_method is a DB column" do
        target_class = double("target_class")
        all_query = double("all_query")
        selected_query = double("selected_query")

        allow(target_class).to receive(:all).and_return(all_query)
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with(:column_names).and_return(true)
        allow(target_class).to receive(:column_names).and_return(%w[id full_name email])
        allow(all_query).to receive(:select).with(:id, :full_name).and_return(selected_query)
        allow(selected_query).to receive(:limit).and_return(selected_query)
        allow(selected_query).to receive(:map).and_return([ [ "John Doe", 1 ] ])
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        config = { "association" => lcp_assoc, "input_options" => { "label_method" => "full_name" } }
        expect(form).to receive(:select)
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "does not apply select when label_method is :to_label (not a column)" do
        target_class = double("target_class")
        all_query = double("all_query")

        allow(target_class).to receive(:all).and_return(all_query)
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with(:column_names).and_return(true)
        allow(target_class).to receive(:column_names).and_return(%w[id name email])
        allow(all_query).to receive(:limit).and_return(all_query)
        allow(all_query).to receive(:map).and_return([ [ "John", 1 ] ])
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition).and_raise(LcpRuby::MetadataError, "not found")

        config = { "association" => lcp_assoc, "input_options" => {} }
        expect(all_query).not_to receive(:select)
        expect(form).to receive(:select)
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "includes group_by column in select when group_by is a DB column" do
        target_class = double("target_class")
        all_query = double("all_query")
        selected_query = double("selected_query")

        allow(target_class).to receive(:all).and_return(all_query)
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with(:column_names).and_return(true)
        allow(target_class).to receive(:column_names).and_return(%w[id name industry])
        allow(all_query).to receive(:select).with(:id, :name, :industry).and_return(selected_query)
        allow(selected_query).to receive(:limit).and_return(selected_query)
        allow(selected_query).to receive(:group_by).and_return({ "tech" => [] })
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        model_def = double("model_def", label_method: "name")
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition).with("contact").and_return(model_def)

        config = {
          "association" => lcp_assoc,
          "input_options" => { "group_by" => "industry" }
        }
        allow(form).to receive(:object).and_return(double("obj", contact_id: nil).tap { |o|
          allow(o).to receive(:send).with(:contact_id).and_return(nil)
        })
        expect(self).to receive(:grouped_options_for_select).and_return("<options>".html_safe)
        expect(form).to receive(:select)
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "includes sort columns in select" do
        target_class = double("target_class")
        all_query = double("all_query")
        sorted_query = double("sorted_query")
        selected_query = double("selected_query")

        allow(target_class).to receive(:all).and_return(all_query)
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with(:column_names).and_return(true)
        allow(target_class).to receive(:column_names).and_return(%w[id name last_name])
        allow(all_query).to receive(:order).with({ "last_name" => "asc" }).and_return(sorted_query)
        allow(sorted_query).to receive(:select).with(:id, :name, :last_name).and_return(selected_query)
        allow(selected_query).to receive(:limit).and_return(selected_query)
        allow(selected_query).to receive(:map).and_return([ [ "Acme", 1 ] ])
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        model_def = double("model_def", label_method: "name")
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition).with("contact").and_return(model_def)

        config = { "association" => lcp_assoc, "input_options" => { "sort" => { "last_name" => "asc" } } }
        expect(form).to receive(:select)
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "gracefully falls back to :to_label when model definition not found" do
        target_class = double("target_class")
        all_query = double("all_query")

        allow(target_class).to receive(:all).and_return(all_query)
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with(:column_names).and_return(true)
        allow(target_class).to receive(:column_names).and_return(%w[id name])
        allow(all_query).to receive(:limit).and_return(all_query)
        allow(all_query).to receive(:map).and_return([])
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition).and_raise(LcpRuby::MetadataError, "not found")

        config = { "association" => lcp_assoc, "input_options" => {} }
        # to_label is not in column_names, so no select optimization
        expect(all_query).not_to receive(:select)
        expect(form).to receive(:select)
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end
    end

    context "with disabled_values" do
      let(:lcp_assoc) do
        double("association", lcp_model?: true, target_model: "contact")
      end

      before do
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition)
          .and_raise(LcpRuby::MetadataError, "not found")
      end

      it "marks options with disabled attribute for static disabled_values" do
        target_class = double("target_class")
        r1 = double("r1", id: 1, to_label: "Active")
        r2 = double("r2", id: 2, to_label: "Disabled")
        r3 = double("r3", id: 3, to_label: "Also Active")

        allow(r1).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r1).to receive(:send).with(:to_label).and_return("Active")
        allow(r2).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r2).to receive(:send).with(:to_label).and_return("Disabled")
        allow(r3).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r3).to receive(:send).with(:to_label).and_return("Also Active")

        allow(target_class).to receive(:all).and_return([ r1, r2, r3 ])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        config = {
          "association" => lcp_assoc,
          "input_options" => { "disabled_values" => [ 2 ] }
        }

        expect(form).to receive(:select).with(
          :contact_id,
          [ [ "Active", 1 ], [ "Disabled", 2, { disabled: "disabled" } ], [ "Also Active", 3 ] ],
          { include_blank: "-- Select --" },
          hash_including("data-lcp-search" => "local")
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "marks options with disabled attribute for disabled_scope" do
        target_class = double("target_class")
        r1 = double("r1", id: 1, to_label: "Active")
        r2 = double("r2", id: 5, to_label: "Archived")

        allow(r1).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r1).to receive(:send).with(:to_label).and_return("Active")
        allow(r2).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r2).to receive(:send).with(:to_label).and_return("Archived")

        disabled_query = double("disabled_query")
        allow(disabled_query).to receive(:pluck).with(:id).and_return([ 5 ])

        allow(target_class).to receive(:all).and_return([ r1, r2 ])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(target_class).to receive(:respond_to?).with("archived").and_return(true)
        allow(target_class).to receive(:send).with("archived").and_return(disabled_query)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        config = {
          "association" => lcp_assoc,
          "input_options" => { "disabled_scope" => "archived" }
        }

        expect(form).to receive(:select).with(
          :contact_id,
          [ [ "Active", 1 ], [ "Archived", 5, { disabled: "disabled" } ] ],
          { include_blank: "-- Select --" },
          hash_including("data-lcp-search" => "local")
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "returns empty disabled set when no disabled config" do
        target_class = double("target_class")
        r1 = double("r1", id: 1, to_label: "Active")

        allow(r1).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r1).to receive(:send).with(:to_label).and_return("Active")

        allow(target_class).to receive(:all).and_return([ r1 ])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        config = { "association" => lcp_assoc, "input_options" => {} }

        expect(form).to receive(:select).with(
          :contact_id,
          [ [ "Active", 1 ] ],
          { include_blank: "-- Select --" },
          hash_including("data-lcp-search" => "local")
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end
    end

    context "with data-lcp-search attributes" do
      let(:lcp_assoc) do
        double("association", lcp_model?: true, target_model: "contact")
      end

      before do
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition)
          .and_raise(LcpRuby::MetadataError, "not found")
      end

      it "adds data-lcp-search='local' by default for association_select" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        config = { "association" => lcp_assoc, "input_options" => {} }
        expect(form).to receive(:select).with(
          :contact_id, [],
          { include_blank: "-- Select --" },
          hash_including("data-lcp-search" => "local")
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "adds data-lcp-search='local' by default for multi_select" do
        through_assoc = double("through_assoc", lcp_model?: true, target_model: "contact", through?: true)
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        config = { "multi_select_association" => through_assoc, "input_options" => {} }
        expect(form).to receive(:select).with(
          :contact_ids, [],
          { include_blank: false },
          hash_including(multiple: true, "data-lcp-search" => "local")
        )
        render_form_input(form, :contact_ids, "multi_select", config, field_def)
      end

      it "adds data-lcp-search='remote' when search: true" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)
        allow(self).to receive(:select_options_url_for).with(:contact_id).and_return("/contacts/select_options?field=contact_id")

        config = {
          "association" => lcp_assoc,
          "input_options" => {
            "search" => true,
            "search_fields" => [ "name" ],
            "per_page" => 20,
            "min_query_length" => 2
          }
        }
        expect(form).to receive(:select).with(
          :contact_id, [],
          { include_blank: "-- Select --" },
          hash_including(
            "data-lcp-search" => "remote",
            "data-lcp-per-page" => 20,
            "data-lcp-min-query" => 2
          )
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end
    end

    context "with label_i18n_scope for enum select" do
      let(:field_def) do
        double("field_def",
          enum?: true,
          enum_value_names: %w[lead qualified proposal],
          type_definition: nil,
          type: "enum")
      end

      it "translates enum labels via i18n scope" do
        I18n.backend.store_translations(:en, {
          deals: { stages: { lead: "New Lead", qualified: "Qualified Lead", proposal: "Proposal Sent" } }
        })

        config = { "input_options" => { "label_i18n_scope" => "deals.stages" } }
        expect(form).to receive(:select).with(:stage,
          [ [ "New Lead", "lead" ], [ "Qualified Lead", "qualified" ], [ "Proposal Sent", "proposal" ] ],
          include_blank: true)
        render_form_input(form, :stage, "select", config, field_def)
      end

      it "falls back to humanize when i18n key is missing" do
        config = { "input_options" => { "label_i18n_scope" => "nonexistent.scope" } }
        expect(form).to receive(:select).with(:stage,
          [ [ "Lead", "lead" ], [ "Qualified", "qualified" ], [ "Proposal", "proposal" ] ],
          include_blank: true)
        render_form_input(form, :stage, "select", config, field_def)
      end

      it "uses humanize when no label_i18n_scope is set" do
        config = { "input_options" => {} }
        expect(form).to receive(:select).with(:stage,
          [ [ "Lead", "lead" ], [ "Qualified", "qualified" ], [ "Proposal", "proposal" ] ],
          include_blank: true)
        render_form_input(form, :stage, "select", config, field_def)
      end
    end

    context "with legacy_scope" do
      let(:lcp_assoc) do
        double("association", lcp_model?: true, target_model: "contact")
      end

      before do
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition)
          .and_raise(LcpRuby::MetadataError, "not found")
      end

      it "includes disabled legacy option when editing and current value is not in options" do
        target_class = double("target_class")
        r1 = double("r1", id: 1, to_label: "Active")
        allow(r1).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r1).to receive(:send).with(:to_label).and_return("Active")

        record_obj = double("record", contact_id: 99, new_record?: false)
        allow(record_obj).to receive(:send).with(:contact_id).and_return(99)

        allow(target_class).to receive(:all).and_return([ r1 ])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        # Legacy scope finds the archived record
        legacy_query = double("legacy_query")
        allow(target_class).to receive(:respond_to?).with("with_archived").and_return(true)
        allow(target_class).to receive(:send).with("with_archived").and_return(legacy_query)
        legacy_record = double("legacy_record", id: 99)
        allow(legacy_record).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(legacy_record).to receive(:send).with(:to_label).and_return("Archived Co")
        allow(legacy_query).to receive(:find_by).with(id: 99).and_return(legacy_record)

        allow(form).to receive(:object).and_return(record_obj)

        config = {
          "association" => lcp_assoc,
          "input_options" => { "legacy_scope" => "with_archived" }
        }

        expect(form).to receive(:select).with(
          :contact_id,
          [
            [ "Active", 1 ],
            [ "Archived Co (Archived)", 99, { disabled: "disabled", class: "lcp-legacy-option" } ]
          ],
          { include_blank: I18n.t("lcp_ruby.select.include_blank") },
          hash_including("data-lcp-search" => "local")
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "does not inject legacy option for new records" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)

        record_obj = double("record", contact_id: nil, new_record?: true)
        allow(record_obj).to receive(:send).with(:contact_id).and_return(nil)
        allow(form).to receive(:object).and_return(record_obj)

        config = {
          "association" => lcp_assoc,
          "input_options" => { "legacy_scope" => "with_archived" }
        }

        expect(form).to receive(:select).with(
          :contact_id, [],
          { include_blank: I18n.t("lcp_ruby.select.include_blank") },
          hash_including("data-lcp-search" => "local")
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end

      it "does not inject legacy option when current value is in normal options" do
        target_class = double("target_class")
        r1 = double("r1", id: 5, to_label: "Active")
        allow(r1).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(r1).to receive(:send).with(:to_label).and_return("Active")

        record_obj = double("record", contact_id: 5, new_record?: false)
        allow(record_obj).to receive(:send).with(:contact_id).and_return(5)

        allow(target_class).to receive(:all).and_return([ r1 ])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("contact").and_return(target_class)
        allow(form).to receive(:object).and_return(record_obj)

        config = {
          "association" => lcp_assoc,
          "input_options" => { "legacy_scope" => "with_archived" }
        }

        expect(form).to receive(:select).with(
          :contact_id,
          [ [ "Active", 5 ] ],
          { include_blank: I18n.t("lcp_ruby.select.include_blank") },
          hash_including("data-lcp-search" => "local")
        )
        render_form_input(form, :contact_id, "association_select", config, field_def)
      end
    end

    context "with allow_inline_create" do
      let(:lcp_assoc) do
        double("association", lcp_model?: true, target_model: "company")
      end

      before do
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition)
          .and_raise(LcpRuby::MetadataError, "not found")
      end

      it "adds inline create data attributes when configured" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("company").and_return(target_class)

        presenter = double("presenter", slug: "deals")
        allow(self).to receive(:respond_to?).and_call_original
        allow(self).to receive(:respond_to?).with(:current_presenter).and_return(true)
        allow(self).to receive(:current_presenter).and_return(presenter)

        lcp_engine = double("lcp_engine")
        allow(self).to receive(:lcp_ruby).and_return(lcp_engine)
        allow(lcp_engine).to receive(:inline_create_path).with(lcp_slug: "deals").and_return("/deals/inline_create")
        allow(lcp_engine).to receive(:inline_create_form_path).with(lcp_slug: "deals").and_return("/deals/inline_create_form")

        config = {
          "association" => lcp_assoc,
          "input_options" => {
            "allow_inline_create" => true,
            "label_method" => "name"
          }
        }

        expect(form).to receive(:select).with(
          :company_id, [],
          { include_blank: I18n.t("lcp_ruby.select.include_blank") },
          hash_including(
            "data-lcp-inline-create" => "true",
            "data-lcp-inline-create-url" => "/deals/inline_create",
            "data-lcp-inline-create-form-url" => "/deals/inline_create_form",
            "data-lcp-target-model" => "company",
            "data-lcp-label-method" => "name"
          )
        )
        render_form_input(form, :company_id, "association_select", config, field_def)
      end

      it "does not add inline create attrs when allow_inline_create is false" do
        target_class = double("target_class")
        allow(target_class).to receive(:all).and_return([])
        allow(target_class).to receive(:respond_to?).and_return(false)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("company").and_return(target_class)

        config = {
          "association" => lcp_assoc,
          "input_options" => {}
        }

        expect(form).to receive(:select) do |_name, _opts, _html_opts, attrs|
          expect(attrs).not_to have_key("data-lcp-inline-create")
        end
        render_form_input(form, :company_id, "association_select", config, field_def)
      end
    end

    context "with radio" do
      let(:field_def) do
        double("field_def",
          enum?: true,
          enum_value_names: %w[unknown known],
          type_definition: nil,
          type: "enum")
      end

      before do
        allow(form).to receive(:radio_button).and_return("<input type='radio'>".html_safe)
      end

      it "renders radio buttons for enum field" do
        expect(form).to receive(:radio_button).with(:address_type, "unknown")
        expect(form).to receive(:radio_button).with(:address_type, "known")
        result = render_form_input(form, :address_type, "radio", {}, field_def)
        expect(result).to include("lcp-radio-group")
        expect(result).to include("lcp-radio-label")
        expect(result).to include("Unknown")
        expect(result).to include("Known")
      end

      it "falls back to text_field when field_def is nil" do
        expect(form).to receive(:text_field)
        render_form_input(form, :address_type, "radio", {}, nil)
      end

      it "falls back to text_field when field is not enum" do
        non_enum = double("field_def", enum?: false)
        expect(form).to receive(:text_field)
        render_form_input(form, :address_type, "radio", {}, non_enum)
      end

      context "with role-based value filtering" do
        let(:field_def) do
          double("field_def",
            enum?: true,
            enum_value_names: %w[unknown known archived],
            type_definition: nil,
            type: "enum")
        end

        before do
          user = double("user", lcp_role: "editor")
          allow(LcpRuby::Current).to receive(:user).and_return(user)
        end

        it "excludes values based on role" do
          config = {
            "input_options" => {
              "exclude_values" => { "editor" => %w[archived] }
            }
          }
          expect(form).to receive(:radio_button).with(:address_type, "unknown")
          expect(form).to receive(:radio_button).with(:address_type, "known")
          expect(form).not_to receive(:radio_button).with(:address_type, "archived")
          render_form_input(form, :address_type, "radio", config, field_def)
        end
      end

      context "with label_i18n_scope" do
        it "translates radio labels via i18n scope" do
          I18n.backend.store_translations(:en, {
            address: { types: { unknown: "Not Set", known: "Has Address" } }
          })

          config = { "input_options" => { "label_i18n_scope" => "address.types" } }
          result = render_form_input(form, :address_type, "radio", config, field_def)
          expect(result).to include("Not Set")
          expect(result).to include("Has Address")
        end
      end
    end

    context "with tree_select" do
      let(:lcp_assoc) do
        double("association", lcp_model?: true, target_model: "category")
      end

      before do
        model_def = double("model_def", label_method: "name")
        allow(LcpRuby).to receive_message_chain(:loader, :model_definition)
          .with("category").and_return(model_def)
      end

      it "renders hidden field, trigger, and dropdown wrapper" do
        target_class = double("target_class")
        root = double("root", id: 1, name: "Root", parent_id: nil)
        child = double("child", id: 2, name: "Child", parent_id: 1)

        allow(root).to receive(:respond_to?).with(:name).and_return(true)
        allow(root).to receive(:send).with(:name).and_return("Root")
        allow(root).to receive(:send).with("parent_id").and_return(nil)
        allow(child).to receive(:respond_to?).with(:name).and_return(true)
        allow(child).to receive(:send).with(:name).and_return("Child")
        allow(child).to receive(:send).with("parent_id").and_return(1)

        query = [ root, child ]
        allow(target_class).to receive(:all).and_return(query)
        allow(query).to receive(:order).and_return(query)
        allow(LcpRuby).to receive_message_chain(:registry, :model_for).with("category").and_return(target_class)

        record_obj = double("record", parent_id: nil)
        allow(record_obj).to receive(:send).with(:parent_id).and_return(nil)
        allow(form).to receive(:object).and_return(record_obj)
        allow(form).to receive(:hidden_field).and_return("<input type='hidden'>".html_safe)

        config = {
          "association" => lcp_assoc,
          "input_options" => {
            "parent_field" => "parent_id",
            "label_method" => "name",
            "max_depth" => 5,
            "sort" => { "name" => "asc" }
          }
        }

        result = render_form_input(form, :parent_id, "tree_select", config, field_def)
        expect(result).to include("lcp-tree-select-wrapper")
        expect(result).to include("lcp-tree-trigger")
        expect(result).to include("lcp-tree-dropdown")
      end

      it "renders number field for non-LCP association" do
        non_lcp = double("association", lcp_model?: false, target_model: "user")
        config = { "association" => non_lcp, "input_options" => {} }
        expect(form).to receive(:number_field).with(:parent_id, placeholder: "ID")
        render_form_input(form, :parent_id, "tree_select", config, field_def)
      end
    end
  end
end
