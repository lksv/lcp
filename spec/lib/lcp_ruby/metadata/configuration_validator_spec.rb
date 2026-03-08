require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe LcpRuby::Metadata::ConfigurationValidator do
  let(:loader) { LcpRuby::Metadata::Loader.new(metadata_path) }
  let(:validator) { described_class.new(loader) }

  before { loader.load_all }

  # Helper to create a temporary metadata directory with YAML files
  def create_metadata(models: [], presenters: [], permissions: [], view_groups: [], menu: nil, pages: [])
    dir = Dir.mktmpdir("lcp_test")
    %w[models presenters permissions views pages].each { |d| FileUtils.mkdir_p(File.join(dir, d)) }

    models.each_with_index do |yaml, i|
      File.write(File.join(dir, "models", "model_#{i}.yml"), yaml)
    end
    presenters.each_with_index do |yaml, i|
      File.write(File.join(dir, "presenters", "presenter_#{i}.yml"), yaml)
    end
    permissions.each_with_index do |yaml, i|
      File.write(File.join(dir, "permissions", "perm_#{i}.yml"), yaml)
    end
    view_groups.each_with_index do |yaml, i|
      File.write(File.join(dir, "views", "vg_#{i}.yml"), yaml)
    end
    pages.each_with_index do |yaml, i|
      File.write(File.join(dir, "pages", "page_#{i}.yml"), yaml)
    end
    File.write(File.join(dir, "menu.yml"), menu) if menu

    dir
  end

  after do
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  def with_metadata(**opts)
    @tmpdir = create_metadata(**opts)
    loader = LcpRuby::Metadata::Loader.new(@tmpdir)
    loader.load_all
    described_class.new(loader)
  end

  # --- Valid configuration (existing fixtures) ---

  context "with valid fixtures" do
    let(:metadata_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

    it "returns valid result" do
      result = validator.validate
      expect(result).to be_valid
      expect(result.errors).to be_empty
    end

    it "produces a readable summary" do
      result = validator.validate
      expect(result.to_s).to include("valid")
    end
  end

  # --- Association validations ---

  context "association target_model does not exist" do
    let(:metadata_path) { "" } # overridden by with_metadata

    it "reports error for unknown target_model" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: order
            fields:
              - { name: title, type: string }
            associations:
              - type: belongs_to
                name: customer
                target_model: customer
                foreign_key: customer_id
        YAML
      )

      result = v.validate
      expect(result).not_to be_valid
      expect(result.errors).to include(
        a_string_matching(/target_model 'customer' does not exist/)
      )
    end
  end

  context "association reciprocity" do
    let(:metadata_path) { "" }

    it "warns when belongs_to has no inverse has_many" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: title, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ]
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/no corresponding has_many\/has_one found on model 'project'/)
      )
    end

    it "does not warn when inverse exists" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
                  foreign_key: project_id
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: title, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ]
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end
  end

  # --- Enum validations ---

  context "enum field validations" do
    let(:metadata_path) { "" }

    it "reports error when enum has no values" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: ticket
            fields:
              - name: priority
                type: enum
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/enum type requires enum_values/)
      )
    end

    it "reports error when default is not in enum_values" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: ticket
            fields:
              - name: priority
                type: enum
                enum_values:
                  - { value: low, label: "Low" }
                  - { value: high, label: "High" }
                default: critical
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/default value 'critical' is not in enum_values/)
      )
    end

    it "passes when default is in enum_values" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: ticket
            fields:
              - name: priority
                type: enum
                enum_values:
                  - { value: low, label: "Low" }
                  - { value: high, label: "High" }
                default: low
        YAML
      )

      result = v.validate
      enum_errors = result.errors.select { |e| e.include?("enum") }
      expect(enum_errors).to be_empty
    end
  end

  # --- Sequence field validations ---

  context "sequence field without gapfree_sequence model" do
    let(:metadata_path) { "" }

    it "reports error when gapfree_sequence model is missing" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: ticket
            fields:
              - { name: code, type: string, sequence: { format: "TKT-%{sequence:06d}" } }
              - { name: title, type: string }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(a_string_matching(/gapfree_sequence model/))
    end
  end

  context "sequence field with invalid scope reference" do
    let(:metadata_path) { "" }

    it "reports error for unknown scope field" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: gapfree_sequence
              table_name: lcp_gapfree_sequences
              fields:
                - { name: seq_model, type: string }
                - { name: seq_field, type: string }
                - { name: scope_key, type: string }
                - { name: current_value, type: integer }
          YAML
          <<~YAML
            model:
              name: ticket
              fields:
                - { name: code, type: string, sequence: { scope: [nonexistent_field], format: "TKT-%{sequence:06d}" } }
                - { name: title, type: string }
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(a_string_matching(/scope 'nonexistent_field' is not a defined field/))
    end
  end

  context "sequence field with valid virtual scope keys" do
    let(:metadata_path) { "" }

    it "accepts _year, _month, _day as scope keys" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: gapfree_sequence
              table_name: lcp_gapfree_sequences
              fields:
                - { name: seq_model, type: string }
                - { name: seq_field, type: string }
                - { name: scope_key, type: string }
                - { name: current_value, type: integer }
          YAML
          <<~YAML
            model:
              name: ticket
              fields:
                - { name: code, type: string, sequence: { scope: [_year], format: "INV-%{_year}-%{sequence:04d}" } }
                - { name: title, type: string }
          YAML
        ]
      )

      result = v.validate
      scope_errors = result.errors.select { |e| e.include?("scope") }
      expect(scope_errors).to be_empty
    end
  end

  context "sequence field with invalid format placeholder" do
    let(:metadata_path) { "" }

    it "warns about unknown placeholder" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: gapfree_sequence
              table_name: lcp_gapfree_sequences
              fields:
                - { name: seq_model, type: string }
                - { name: seq_field, type: string }
                - { name: scope_key, type: string }
                - { name: current_value, type: integer }
          YAML
          <<~YAML
            model:
              name: ticket
              fields:
                - { name: code, type: string, sequence: { format: "TKT-%{nonexistent}-%{sequence:06d}" } }
                - { name: title, type: string }
          YAML
        ]
      )

      result = v.validate
      expect(result.warnings).to include(a_string_matching(/unknown placeholder.*nonexistent/))
    end
  end

  context "sequence field with invalid assign_on" do
    let(:metadata_path) { "" }

    it "reports error for invalid assign_on value" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: gapfree_sequence
              table_name: lcp_gapfree_sequences
              fields:
                - { name: seq_model, type: string }
                - { name: seq_field, type: string }
                - { name: scope_key, type: string }
                - { name: current_value, type: integer }
          YAML
          <<~YAML
            model:
              name: ticket
              fields:
                - { name: code, type: string, sequence: { format: "TKT-%{sequence:06d}", assign_on: invalid } }
                - { name: title, type: string }
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(a_string_matching(/invalid assign_on/))
    end
  end

  # --- Event validations ---

  context "event field_change references unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: order
            fields:
              - { name: title, type: string }
            events:
              - name: on_nonexistent_change
                type: field_change
                field: nonexistent_field
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/field_change references unknown field 'nonexistent_field'/)
      )
    end
  end

  # --- Presenter validations ---

  context "presenter references unknown model" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      # The Loader's own validate_references raises before the validator runs.
      # This test confirms that protection layer works.
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ]
            presenter:
              name: ghost
              model: ghost
              slug: ghosts
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown model/)
    end
  end

  context "presenter table_columns reference unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
                - { field: nonexistent_col }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/references unknown field 'nonexistent_col'/)
      )
    end
  end

  context "presenter form references unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Info"
                  fields:
                    - { field: bad_field }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/form:.*references unknown field 'bad_field'/)
      )
    end
  end

  context "presenter predefined_filters reference unknown scope" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
            scopes:
              - name: active
                where: { title: "x" }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            search:
              enabled: true
              predefined_filters:
                - { name: missing, label: "Missing", scope: nonexistent_scope }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown scope 'nonexistent_scope'/)
      )
    end
  end

  # --- Permission validations ---

  context "permission references unknown CRUD action" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show, invent]
                fields: { readable: all, writable: all }
            default_role: admin
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown CRUD action 'invent'/)
      )
    end
  end

  context "permission references unknown presenter" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show]
                fields: { readable: all, writable: all }
                presenters: [ghost_presenter]
            default_role: admin
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown presenter 'ghost_presenter'/)
      )
    end
  end

  context "permission record_rules reference unknown field" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show, create, update]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: test_rule
                condition: { field: ghost_field, operator: eq, value: x }
                effect:
                  deny_crud: [update]
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/references unknown field 'ghost_field'/)
      )
    end
  end

  context "permission record_rules use unknown operator" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: test_rule
                condition: { field: title, operator: fuzzy_match, value: x }
                effect:
                  deny_crud: [show]
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/unknown operator 'fuzzy_match'/)
      )
    end
  end

  # --- Uniqueness validations ---

  context "duplicate presenter slugs" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: projects
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/Duplicate slug 'projects'/)
      )
    end
  end

  context "duplicate table names" do
    let(:metadata_path) { "" }

    it "reports error" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: item
              table_name: products
              fields:
                - { name: title, type: string }
          YAML
          <<~YAML
            model:
              name: product
              table_name: products
              fields:
                - { name: name, type: string }
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/Duplicate table_name 'products'/)
      )
    end
  end

  # --- Polymorphic association validations ---

  context "polymorphic belongs_to" do
    let(:metadata_path) { "" }

    it "does not error when polymorphic belongs_to has no target_model" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
      )

      result = v.validate
      expect(result).to be_valid
    end

    it "does not warn about missing reciprocity for polymorphic belongs_to" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end

    it "does not warn about missing reciprocity for has_many with as" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: post
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: comments
                  target_model: comment
                  as: commentable
          YAML
          <<~YAML
            model:
              name: comment
              fields:
                - { name: body, type: text }
              associations:
                - type: belongs_to
                  name: commentable
                  polymorphic: true
                  required: false
          YAML
        ]
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end
  end

  # --- Through association validations ---

  context "through associations" do
    let(:metadata_path) { "" }

    it "does not warn about reciprocity for through associations" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: post
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: taggings
                  target_model: tagging
                - type: has_many
                  name: tags
                  target_model: tag
                  through: taggings
          YAML
          <<~YAML,
            model:
              name: tagging
              fields: []
              associations:
                - type: belongs_to
                  name: post
                  target_model: post
                - type: belongs_to
                  name: tag
                  target_model: tag
          YAML
          <<~YAML
            model:
              name: tag
              fields:
                - { name: label, type: string }
              associations:
                - type: has_many
                  name: taggings
                  target_model: tagging
          YAML
        ]
      )

      result = v.validate
      reciprocity_warnings = result.warnings.select { |w| w.include?("no corresponding") }
      expect(reciprocity_warnings).to be_empty
    end

    it "errors when through references non-existent association" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: post
            fields:
              - { name: title, type: string }
            associations:
              - type: has_many
                name: tags
                through: nonexistent
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/through 'nonexistent' does not match any association/)
      )
    end

    it "passes when through references existing association" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: post
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: taggings
                  target_model: tagging
                - type: has_many
                  name: tags
                  through: taggings
          YAML
          <<~YAML
            model:
              name: tagging
              fields: []
              associations:
                - type: belongs_to
                  name: post
                  target_model: post
          YAML
        ]
      )

      result = v.validate
      through_errors = result.errors.select { |e| e.include?("through") }
      expect(through_errors).to be_empty
    end
  end

  # --- View group validations ---
  # Note: Structural errors (unknown model/presenter, presenter in multiple groups,
  # primary not in views list) are caught by Loader.validate_references at load time,
  # before the ConfigurationValidator runs. Those are tested in loader_view_groups_spec.
  # The ConfigurationValidator adds position uniqueness warnings.

  context "view group references unknown model" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ]
            view_group:
              name: bad_group
              model: nonexistent
              primary: project
              views:
                - page: project
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown model/)
    end
  end

  context "view group references unknown page" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ]
            view_group:
              name: bad_group
              model: project
              primary: project
              views:
                - page: project
                - page: ghost_page
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown page/)
    end
  end

  context "page in multiple view groups" do
    let(:metadata_path) { "" }

    it "is caught by loader.validate_references at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [
            <<~YAML,
              presenter:
                name: project
                model: project
                slug: projects
            YAML
            <<~YAML
              presenter:
                name: project_public
                model: project
                slug: public-projects
            YAML
          ],
          view_groups: [
            <<~YAML,
              view_group:
                name: group_a
                model: project
                primary: project
                views:
                  - page: project
            YAML
            <<~YAML
              view_group:
                name: group_b
                model: project
                primary: project_public
                views:
                  - page: project_public
                  - page: project
            YAML
          ]
        )
      }.to raise_error(LcpRuby::MetadataError, /multiple view groups/)
    end
  end

  context "view group primary not in views list" do
    let(:metadata_path) { "" }

    it "is caught by ViewGroupDefinition.validate! at load time" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [
            <<~YAML,
              presenter:
                name: project
                model: project
                slug: projects
            YAML
            <<~YAML
              presenter:
                name: project_public
                model: project
                slug: public-projects
            YAML
          ],
          view_groups: [ <<~YAML ]
            view_group:
              name: bad_primary
              model: project
              primary: project_public
              views:
                - page: project
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /primary page 'project_public'.*not in the views list/)
    end
  end

  context "view group duplicate navigation positions" do
    let(:metadata_path) { "" }

    it "warns about duplicate positions" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: public-projects
          YAML
        ],
        view_groups: [
          <<~YAML,
            view_group:
              name: group_a
              model: project
              primary: project
              navigation:
                menu: main
                position: 1
              views:
                - page: project
          YAML
          <<~YAML
            view_group:
              name: group_b
              model: project
              primary: project_public
              navigation:
                menu: main
                position: 1
              views:
                - page: project_public
          YAML
        ]
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/navigation position 1.*also used by/)
      )
    end
  end

  context "valid view group configuration" do
    let(:metadata_path) { "" }

    it "passes validation" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: public-projects
          YAML
        ],
        view_groups: [ <<~YAML ]
          view_group:
            name: projects
            model: project
            primary: project
            navigation:
              menu: main
              position: 1
            views:
              - page: project
                label: "Admin"
              - page: project_public
                label: "Public"
        YAML
      )

      result = v.validate
      vg_errors = result.errors.select { |e| e.include?("View group") || e.include?("view group") }
      expect(vg_errors).to be_empty
    end
  end

  context "view group with valid switcher config" do
    let(:metadata_path) { "" }

    it "passes validation with switcher: [show]" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: public-projects
          YAML
        ],
        view_groups: [ <<~YAML ]
          view_group:
            name: projects
            model: project
            primary: project
            switcher:
              - show
            views:
              - page: project
              - page: project_public
        YAML
      )

      result = v.validate
      vg_errors = result.errors.select { |e| e.include?("View group") || e.include?("switcher") }
      expect(vg_errors).to be_empty
    end

    it "reports error for invalid switcher contexts" do
      # Build a ViewGroupDefinition with a valid array, then stub switcher_config
      # to return an invalid value to exercise the validator's own check.
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: public-projects
          YAML
        ],
        view_groups: [ <<~YAML ]
          view_group:
            name: projects
            model: project
            primary: project
            switcher:
              - show
            views:
              - page: project
              - page: project_public
        YAML
      )

      # Stub the switcher_config to return an invalid context that parse_switcher would normally reject
      vg = v.send(:loader).view_group_definitions["projects"]
      allow(vg).to receive(:switcher_config).and_return(%w[edit])

      result = v.validate
      switcher_errors = result.errors.select { |e| e.include?("switcher") }
      expect(switcher_errors).to include(
        a_string_matching(/invalid switcher contexts: edit/)
      )
    end

    it "passes validation with switcher: false" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [
          <<~YAML,
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          <<~YAML
            presenter:
              name: project_public
              model: project
              slug: public-projects
          YAML
        ],
        view_groups: [ <<~YAML ]
          view_group:
            name: projects
            model: project
            primary: project
            switcher: false
            views:
              - page: project
              - page: project_public
        YAML
      )

      result = v.validate
      vg_errors = result.errors.select { |e| e.include?("View group") || e.include?("switcher") }
      expect(vg_errors).to be_empty
    end
  end

  # --- Polymorphic _type in presenter/permission fields ---

  context "polymorphic _type field in presenter" do
    let(:metadata_path) { "" }

    it "accepts commentable_type as valid presenter field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: comments
            model: comment
            slug: comments
            index:
              table_columns:
                - { field: body }
                - { field: commentable_id }
                - { field: commentable_type }
        YAML
      )

      result = v.validate
      type_errors = result.errors.select { |e| e.include?("commentable_type") }
      expect(type_errors).to be_empty
    end

    it "still reports error for truly unknown fields on polymorphic model" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - type: belongs_to
                name: commentable
                polymorphic: true
                required: false
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: comments
            model: comment
            slug: comments
            index:
              table_columns:
                - { field: nonexistent }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/references unknown field 'nonexistent'/)
      )
    end
  end

  # --- Scope field validations ---

  context "scope references unknown field" do
    let(:metadata_path) { "" }

    it "warns about unknown where field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            scopes:
              - name: active
                where: { ghost_field: "active" }
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/scope 'active':.*unknown field 'ghost_field'/)
      )
    end
  end

  # --- Virtual field validations ---

  context "virtual field with service accessor" do
    let(:metadata_path) { "" }

    it "errors when accessor service column references non-existent field" do
      LcpRuby::Services::Registry.register("accessors", "json_field", ->(_r, _f) { })

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: product
            fields:
              - { name: title, type: string }
              - name: color
                type: string
                source:
                  service: json_field
                  options:
                    column: nonexistent
                    key: color
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/source references column 'nonexistent' which is not a defined field/)
      )
    ensure
      LcpRuby::Services::Registry.clear!
    end

    it "warns when virtual field has transforms" do
      LcpRuby::Services::Registry.register("accessors", "json_field", ->(_r, _f) { })

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: product
            fields:
              - { name: title, type: string }
              - { name: data, type: json }
              - name: color
                type: string
                transforms: [strip]
                source:
                  service: json_field
                  options:
                    column: data
                    key: color
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/transforms are ignored on virtual fields/)
      )
    ensure
      LcpRuby::Services::Registry.clear!
    end

    it "passes for valid virtual field configuration" do
      LcpRuby::Services::Registry.register("accessors", "json_field", ->(_r, _f) { })

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: product
            fields:
              - { name: title, type: string }
              - { name: data, type: json }
              - name: color
                type: string
                source:
                  service: json_field
                  options:
                    column: data
                    key: color
        YAML
      )

      result = v.validate
      virtual_errors = result.errors.select { |e| e.include?("accessor") || e.include?("virtual") }
      expect(virtual_errors).to be_empty
    ensure
      LcpRuby::Services::Registry.clear!
    end
  end

  # --- CRM integration fixtures (complex, multi-model) ---

  context "with CRM integration fixtures" do
    let(:metadata_path) { File.expand_path("../../../fixtures/integration/crm", __dir__) }
    let(:loader) do
      LcpRuby::Types::BuiltInTypes.register_all!
      LcpRuby::Metadata::Loader.new(metadata_path)
    end

    it "validates without errors" do
      result = validator.validate
      expect(result).to be_valid
    end
  end

  # --- Condition validation ---

  context "condition with invalid regex pattern" do
    let(:metadata_path) { "" }

    it "reports error for invalid regex in matches operator" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: code, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                    - field: code
                      visible_when: { field: title, operator: matches, value: "[invalid" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/invalid regex pattern '\[invalid'/)
      )
    end

    it "accepts valid regex in matches operator" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: code, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                    - field: code
                      visible_when: { field: title, operator: matches, value: "^[A-Z]+$" }
        YAML
      )

      result = v.validate
      regex_errors = result.errors.select { |e| e.include?("regex") }
      expect(regex_errors).to be_empty
    end
  end

  context "condition validation on fields and sections" do
    let(:metadata_path) { "" }

    it "reports error for unknown field in field-level disable_when" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      disable_when: { field: ghost_field, operator: eq, value: x }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/disable_when.*references unknown field 'ghost_field'/)
      )
    end

    it "reports error for unknown field in section-level visible_when" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  visible_when: { field: nonexistent, operator: eq, value: x }
                  fields:
                    - { field: title }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/section 'Details', visible_when.*references unknown field 'nonexistent'/)
      )
    end

    it "accepts valid visible_when on show section" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Metrics"
                  visible_when: { field: status, operator: not_eq, value: draft }
                  fields:
                    - { field: title }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("visible_when") }
      expect(condition_errors).to be_empty
    end

    it "reports error for unknown field in show section visible_when" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Metrics"
                  visible_when: { field: nonexistent, operator: eq, value: x }
                  fields:
                    - { field: title }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/section 'Metrics', visible_when.*references unknown field 'nonexistent'/)
      )
    end

    it "reports error for unknown field in association_list visible_when" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: project
            fields:
              - { name: title, type: string }
            associations:
              - { type: has_many, name: tasks, target_model: task }
        YAML
          model:
            name: task
            fields:
              - { name: name, type: string }
            associations:
              - { type: belongs_to, name: project, target_model: project }
        YAML2
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Tasks"
                  type: association_list
                  association: tasks
                  visible_when: { field: ghost_field, operator: eq, value: x }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/section 'Tasks', visible_when.*references unknown field 'ghost_field'/)
      )
    end

    it "reports error for action disable_when with unknown operator" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            actions:
              single:
                - name: close
                  type: custom
                  disable_when: { field: title, operator: fuzzy_match, value: x }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/disable_when.*uses unknown operator 'fuzzy_match'/)
      )
    end

    it "skips validation for service conditions" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { service: some_service }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("visible_when") || e.include?("disable_when") }
      expect(condition_errors).to be_empty
    end
  end

  # --- Operator-type compatibility validations ---

  context "operator-type compatibility" do
    let(:metadata_path) { "" }

    it "reports error for gt operator on string field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { field: title, operator: gt, value: "100" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/operator 'gt' is not compatible with field 'title'.*type 'string'/)
      )
    end

    it "reports error for matches operator on integer field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: priority, type: integer }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { field: priority, operator: matches, value: '^\\d+$' }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/operator 'matches' is not compatible with field 'priority'.*type 'integer'/)
      )
    end

    it "accepts gt on decimal field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: budget, type: decimal }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { field: budget, operator: gt, value: 1000 }
        YAML
      )

      result = v.validate
      compat_errors = result.errors.select { |e| e.include?("not compatible") }
      expect(compat_errors).to be_empty
    end

    it "accepts matches on custom type with string base" do
      LcpRuby::Types::TypeRegistry.register("email",
        LcpRuby::Types::TypeDefinition.new(name: "email", base_type: "string"))

      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: contact
            fields:
              - { name: name, type: string }
              - { name: email, type: email }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: contact
            model: contact
            slug: contacts
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: name
                      visible_when: { field: email, operator: matches, value: "^[^@]+@" }
        YAML
      )

      result = v.validate
      compat_errors = result.errors.select { |e| e.include?("not compatible") }
      expect(compat_errors).to be_empty
    ensure
      LcpRuby::Types::TypeRegistry.clear!
    end

    it "accepts eq on any field type" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
              - { name: priority, type: integer }
              - { name: active, type: boolean }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { field: priority, operator: eq, value: "1" }
                    - field: priority
                      visible_when: { field: active, operator: eq, value: "true" }
        YAML
      )

      result = v.validate
      compat_errors = result.errors.select { |e| e.include?("not compatible") }
      expect(compat_errors).to be_empty
    end

    it "reports error for gt on string field in record_rules" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show, create, update]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: test_rule
                condition: { field: title, operator: gt, value: "abc" }
                effect:
                  deny_crud: [update]
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/operator 'gt' is not compatible with field 'title'.*type 'string'/)
      )
    end

    it "skips unknown field in condition on custom_fields enabled model" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
            options:
              custom_fields: true
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { field: cf_custom_status, operator: eq, value: "active" }
        YAML
      )

      result = v.validate
      # Should not report unknown field error for cf_custom_status
      field_errors = result.errors.select { |e| e.include?("references unknown field 'cf_custom_status'") }
      expect(field_errors).to be_empty
    end
  end

  # --- Display template validations ---

  context "display template references unknown field" do
    let(:metadata_path) { "" }

    it "warns about unknown field in template placeholder" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            display_templates:
              default:
                template: "{title} - {nonexistent}"
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/display template 'default'.*unknown field 'nonexistent'/)
      )
    end

    it "does not warn for valid field references" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            display_templates:
              default:
                template: "{title}"
                subtitle: "{created_at}"
        YAML
      )

      result = v.validate
      template_warnings = result.warnings.select { |w| w.include?("display template") }
      expect(template_warnings).to be_empty
    end

    it "skips dot-path references in templates" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            display_templates:
              default:
                template: "{title} ({category.name})"
        YAML
      )

      result = v.validate
      template_warnings = result.warnings.select { |w| w.include?("display template") }
      expect(template_warnings).to be_empty
    end
  end

  # --- Nested fields association validation ---

  context "nested_fields references unknown association" do
    let(:metadata_path) { "" }

    it "reports error for unknown association" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Tasks"
                  type: nested_fields
                  association: tasks
                  fields:
                    - { field: name }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested_fields references unknown association 'tasks'/)
      )
    end

    it "passes when association exists" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: name, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            form:
              sections:
                - title: "Tasks"
                  type: nested_fields
                  association: tasks
                  fields:
                    - { field: name }
        YAML
      )

      result = v.validate
      nested_errors = result.errors.select { |e| e.include?("nested_fields") }
      expect(nested_errors).to be_empty
    end
  end

  # --- Association list section validation ---

  context "association_list references unknown association" do
    let(:metadata_path) { "" }

    it "reports error for unknown association" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Comments"
                  type: association_list
                  association: comments
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/association_list references unknown association 'comments'/)
      )
    end

    it "passes when association exists" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: comments
                  target_model: comment
          YAML
          <<~YAML
            model:
              name: comment
              fields:
                - { name: body, type: text }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Comments"
                  type: association_list
                  association: comments
        YAML
      )

      result = v.validate
      assoc_errors = result.errors.select { |e| e.include?("association_list") }
      expect(assoc_errors).to be_empty
    end
  end

  # --- Default sort validation ---

  context "presenter default_sort" do
    let(:metadata_path) { "" }

    it "reports error for unknown sort field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              default_sort:
                field: nonexistent
                direction: asc
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/default_sort.*unknown field 'nonexistent'/)
      )
    end

    it "reports error for invalid direction" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              default_sort:
                field: title
                direction: upward
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/default_sort.*invalid direction 'upward'/)
      )
    end

    it "passes with valid sort config" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              default_sort:
                field: created_at
                direction: desc
        YAML
      )

      result = v.validate
      sort_errors = result.errors.select { |e| e.include?("default_sort") }
      expect(sort_errors).to be_empty
    end
  end

  # --- Includes/eager_load validation ---

  context "presenter includes references unknown association" do
    let(:metadata_path) { "" }

    it "warns about unknown association in includes" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: name, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            index:
              table_columns:
                - { field: title }
              includes: [nonexistent_assoc]
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/index\.includes.*unknown association 'nonexistent_assoc'/)
      )
    end

    it "does not warn for valid association in eager_load" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: tasks
                  target_model: task
          YAML
          <<~YAML
            model:
              name: task
              fields:
                - { name: name, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            show:
              layout:
                - section: "Info"
                  fields:
                    - { field: title }
              eager_load: [tasks]
        YAML
      )

      result = v.validate
      includes_warnings = result.warnings.select { |w| w.include?("eager_load") }
      expect(includes_warnings).to be_empty
    end
  end

  # --- Custom action name validation ---

  context "custom action with built-in name" do
    let(:metadata_path) { "" }

    it "warns when custom action uses built-in name" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            actions:
              single:
                - name: destroy
                  type: custom
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/custom action uses built-in name 'destroy'/)
      )
    end

    it "does not warn for properly named custom actions" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: project
            model: project
            slug: projects
            actions:
              single:
                - name: archive
                  type: custom
        YAML
      )

      result = v.validate
      action_warnings = result.warnings.select { |w| w.include?("custom action") }
      expect(action_warnings).to be_empty
    end
  end

  # --- Menu validations ---

  context "menu references unknown view group" do
    let(:metadata_path) { "" }

    it "is caught by loader at load time for unknown view group" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ],
            view_group:
              name: projects
              model: project
              primary: project
              views:
                - page: project
          YAML
          menu: <<~YAML
            menu:
              top_menu:
                - view_group: projects
                - view_group: nonexistent_group
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown view group/)
    end

    it "is caught by loader at load time for unknown view group in children" do
      expect {
        with_metadata(
          models: [ <<~YAML ],
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
          presenters: [ <<~YAML ],
            presenter:
              name: project
              model: project
              slug: projects
          YAML
          view_groups: [ <<~YAML ],
            view_group:
              name: projects
              model: project
              primary: project
              views:
                - page: project
          YAML
          menu: <<~YAML
            menu:
              sidebar_menu:
                - label: "Group"
                  children:
                    - view_group: projects
                    - view_group: ghost_group
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown view group/)
    end

    it "passes with valid menu" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ],
          presenter:
            name: project
            model: project
            slug: projects
        YAML
        view_groups: [ <<~YAML ],
          view_group:
            name: projects
            model: project
            primary: project
            views:
              - page: project
        YAML
        menu: <<~YAML
          menu:
            top_menu:
              - view_group: projects
        YAML
      )

      result = v.validate
      menu_errors = result.errors.select { |e| e.include?("Menu") }
      expect(menu_errors).to be_empty
    end
  end

  context "menu visible_when references undefined role" do
    let(:metadata_path) { "" }

    it "warns about undefined role" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ],
          presenter:
            name: project
            model: project
            slug: projects
        YAML
        permissions: [ <<~YAML ],
          permissions:
            model: project
            roles:
              admin:
                crud: [index, show]
                fields: { readable: all }
            default_role: admin
        YAML
        view_groups: [ <<~YAML ],
          view_group:
            name: projects
            model: project
            primary: project
            views:
              - page: project
        YAML
        menu: <<~YAML
          menu:
            top_menu:
              - view_group: projects
                visible_when:
                  role: [admin, superuser]
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/visible_when references undefined role 'superuser'/)
      )
    end
  end

  # --- Custom fields validations ---

  context "custom_fields enabled" do
    let(:metadata_path) { "" }

    it "does not warn about custom_data (auto-added at runtime)" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
            options:
              custom_fields: true
        YAML
      )

      result = v.validate
      cf_warnings = result.warnings.select { |w| w.include?("custom_fields") || w.include?("custom_data") }
      expect(cf_warnings).to be_empty
    end
  end

  # --- Positioning validations ---

  context "positioning field not defined" do
    let(:metadata_path) { "" }

    it "reports error when positioning field is missing" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: stage
            fields:
              - { name: title, type: string }
            positioning: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning field 'position' is not defined/))
    end
  end

  context "positioning field wrong type" do
    let(:metadata_path) { "" }

    it "reports error when positioning field is not integer" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: string }
            positioning: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning field 'position' must be type 'integer'/))
    end
  end

  context "positioning field is virtual" do
    let(:metadata_path) { "" }

    it "reports error when positioning field is virtual" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: metadata, type: json }
              - name: position
                type: integer
                source:
                  service: json_field
                  options:
                    column: metadata
                    key: position
            positioning: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning field 'position' cannot be a virtual field/))
    end
  end

  context "positioning scope references unknown field" do
    let(:metadata_path) { "" }

    it "reports error when scope field does not exist" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: integer }
            positioning:
              scope: nonexistent_id
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/positioning scope 'nonexistent_id' is not a defined field or FK/))
    end
  end

  context "valid positioning config" do
    let(:metadata_path) { "" }

    it "passes validation with correct positioning config" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: integer }
            positioning: true
        YAML
      )

      result = v.validate
      positioning_errors = result.errors.select { |e| e.include?("positioning") }
      expect(positioning_errors).to be_empty
    end
  end

  context "presenter reorderable without model positioning" do
    let(:metadata_path) { "" }

    it "reports error when reorderable is true but model has no positioning" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: stage
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: stages
            model: stage
            slug: stages
            index:
              reorderable: true
              table_columns:
                - { field: title }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/reorderable is true but model 'stage' has no positioning/))
    end
  end

  # --- Group model validations ---

  context "group_source :model with valid group models" do
    let(:metadata_path) { "" }

    it "passes validation with correct group, membership, and role mapping models" do
      LcpRuby.configuration.group_source = :model
      LcpRuby.configuration.group_role_mapping_model = "group_role_mapping"

      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: group
              fields:
                - { name: name, type: string, validations: [{ type: uniqueness }] }
                - { name: active, type: boolean }
          YAML
          <<~YAML,
            model:
              name: group_membership
              fields:
                - { name: user_id, type: integer }
              associations:
                - { name: group, type: belongs_to, target_model: group }
          YAML
          <<~YAML
            model:
              name: group_role_mapping
              fields:
                - { name: role_name, type: string }
              associations:
                - { name: group, type: belongs_to, target_model: group }
          YAML
        ]
      )

      result = v.validate
      group_errors = result.errors.select { |e| e.include?("group") }
      expect(group_errors).to be_empty
    ensure
      LcpRuby.configuration.group_source = :none
      LcpRuby.configuration.group_role_mapping_model = nil
    end
  end

  context "group_source :model with missing group model" do
    let(:metadata_path) { "" }

    it "reports error when group model is not defined" do
      LcpRuby.configuration.group_source = :model

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: something_else
            fields:
              - { name: title, type: string }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/group model 'group' is not defined/))
    ensure
      LcpRuby.configuration.group_source = :none
    end
  end

  context "group_source :model with invalid group contract" do
    let(:metadata_path) { "" }

    it "reports contract errors for group model" do
      LcpRuby.configuration.group_source = :model

      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: group
              fields:
                - { name: label, type: string }
          YAML
          <<~YAML
            model:
              name: group_membership
              fields:
                - { name: user_id, type: integer }
              associations:
                - { name: group, type: belongs_to, target_model: group }
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(match(/must have a 'name' field/))
    ensure
      LcpRuby.configuration.group_source = :none
    end
  end

  context "group_source :model with missing membership model" do
    let(:metadata_path) { "" }

    it "reports error when membership model is not defined" do
      LcpRuby.configuration.group_source = :model

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: group
            fields:
              - { name: name, type: string, validations: [{ type: uniqueness }] }
              - { name: active, type: boolean }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(match(/group membership model 'group_membership' is not defined/))
    ensure
      LcpRuby.configuration.group_source = :none
    end
  end

  context "group_source :model with missing role mapping model" do
    let(:metadata_path) { "" }

    it "reports error when configured role mapping model is not defined" do
      LcpRuby.configuration.group_source = :model
      LcpRuby.configuration.group_role_mapping_model = "group_role_mapping"

      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: group
              fields:
                - { name: name, type: string, validations: [{ type: uniqueness }] }
                - { name: active, type: boolean }
          YAML
          <<~YAML
            model:
              name: group_membership
              fields:
                - { name: user_id, type: integer }
              associations:
                - { name: group, type: belongs_to, target_model: group }
          YAML
        ]
      )

      result = v.validate
      expect(result.errors).to include(match(/group role mapping model 'group_role_mapping' is not defined/))
    ensure
      LcpRuby.configuration.group_source = :none
      LcpRuby.configuration.group_role_mapping_model = nil
    end
  end

  context "group_source :model with both group and membership models missing" do
    let(:metadata_path) { "" }

    it "reports errors for all missing models (no early return)" do
      LcpRuby.configuration.group_source = :model
      LcpRuby.configuration.group_role_mapping_model = "group_role_mapping"

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: something_else
            fields:
              - { name: title, type: string }
        YAML
      )

      result = v.validate
      group_errors = result.errors.select { |e| e.include?("group") }

      # Should report errors for BOTH group and membership models, not just the first
      expect(group_errors).to include(match(/group model 'group' is not defined/))
      expect(group_errors).to include(match(/group membership model 'group_membership' is not defined/))
      expect(group_errors).to include(match(/group role mapping model 'group_role_mapping' is not defined/))
    ensure
      LcpRuby.configuration.group_source = :none
      LcpRuby.configuration.group_role_mapping_model = nil
    end
  end

  context "group_source :model with contract errors and missing membership" do
    let(:metadata_path) { "" }

    it "reports both contract errors and missing model errors" do
      LcpRuby.configuration.group_source = :model

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: group
            fields:
              - { name: label, type: string }
        YAML
      )

      result = v.validate
      group_errors = result.errors.select { |e| e.include?("group") || e.include?("Group") }

      # Should report contract error for group model AND missing membership model
      expect(group_errors).to include(match(/must have a 'name' field/))
      expect(group_errors).to include(match(/group membership model 'group_membership' is not defined/))
    ensure
      LcpRuby.configuration.group_source = :none
    end
  end

  context "group_source :none skips group validation" do
    let(:metadata_path) { "" }

    it "does not validate group models when group_source is :none" do
      LcpRuby.configuration.group_source = :none

      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: project
            fields:
              - { name: title, type: string }
        YAML
      )

      result = v.validate
      group_errors = result.errors.select { |e| e.include?("group") }
      expect(group_errors).to be_empty
    end
  end

  context "positioning field in form section" do
    let(:metadata_path) { "" }

    it "adds warning when positioning field appears in form" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: stage
            fields:
              - { name: title, type: string }
              - { name: position, type: integer }
            positioning: true
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: stages
            model: stage
            slug: stages
            index:
              reorderable: true
              table_columns:
                - { field: title }
            form:
              sections:
                - title: Details
                  fields:
                    - { field: title }
                    - { field: position }
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(match(/positioning field 'position' appears in a form section/))
    end
  end

  # --- Nested field reference validations (association-based nested_fields) ---

  context "nested field references" do
    let(:metadata_path) { "" }

    let(:parent_model) do
      <<~YAML
        model:
          name: invoice
          fields:
            - { name: number, type: string }
          associations:
            - type: has_many
              name: line_items
              target_model: line_item
              foreign_key: invoice_id
              dependent: destroy
              nested_attributes:
                allow_destroy: true
      YAML
    end

    let(:child_model) do
      <<~YAML
        model:
          name: line_item
          fields:
            - { name: description, type: string }
            - { name: quantity, type: integer }
            - { name: unit_price, type: decimal }
          associations:
            - type: belongs_to
              name: invoice
              target_model: invoice
              foreign_key: invoice_id
      YAML
    end

    it "accepts valid field references on the target model" do
      v = with_metadata(
        models: [ parent_model, child_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: invoice
            model: invoice
            slug: invoices
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: description }
                    - { field: quantity }
                    - { field: unit_price }
        YAML
      )

      result = v.validate
      field_errors = result.errors.select { |e| e.include?("does not exist on target model") }
      expect(field_errors).to be_empty
    end

    it "accepts FK field references on the target model" do
      v = with_metadata(
        models: [ parent_model, child_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: invoice
            model: invoice
            slug: invoices
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: description }
                    - { field: invoice_id }
        YAML
      )

      result = v.validate
      field_errors = result.errors.select { |e| e.include?("does not exist on target model") }
      expect(field_errors).to be_empty
    end

    it "reports error for unknown field on the target model" do
      v = with_metadata(
        models: [ parent_model, child_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: invoice
            model: invoice
            slug: invoices
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: description }
                    - { field: nonexistent_field }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/field 'nonexistent_field' does not exist on target model 'line_item'/)
      )
    end

    it "reports errors for multiple unknown fields" do
      v = with_metadata(
        models: [ parent_model, child_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: invoice
            model: invoice
            slug: invoices
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: bad_one }
                    - { field: bad_two }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/field 'bad_one' does not exist on target model 'line_item'/),
        a_string_matching(/field 'bad_two' does not exist on target model 'line_item'/)
      )
    end

    it "validates field references in sub_sections" do
      v = with_metadata(
        models: [ parent_model, child_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: invoice
            model: invoice
            slug: invoices
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  sub_sections:
                    - title: "Basics"
                      fields:
                        - { field: description }
                        - { field: typo_field }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/field 'typo_field' does not exist on target model 'line_item'/)
      )
    end
  end

  # --- Nested field condition validations ---

  context "nested field conditions" do
    let(:metadata_path) { "" }

    let(:order_model) do
      <<~YAML
        model:
          name: order
          fields:
            - { name: title, type: string }
          associations:
            - type: has_many
              name: line_items
              target_model: line_item
              foreign_key: order_id
              dependent: destroy
              nested_attributes:
                allow_destroy: true
      YAML
    end

    let(:line_item_model) do
      <<~YAML
        model:
          name: line_item
          fields:
            - { name: item_type, type: string }
            - { name: discount_percent, type: decimal }
            - { name: notes, type: text }
          associations:
            - type: belongs_to
              name: order
              target_model: order
              foreign_key: order_id
      YAML
    end

    it "accepts valid nested field conditions referencing target model fields" do
      v = with_metadata(
        models: [ order_model, line_item_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: item_type }
                    - field: discount_percent
                      visible_when: { field: item_type, operator: eq, value: discount }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("nested field") }
      expect(condition_errors).to be_empty
    end

    it "reports error for nested field condition referencing unknown target model field" do
      v = with_metadata(
        models: [ order_model, line_item_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: item_type }
                    - field: discount_percent
                      visible_when: { field: nonexistent_field, operator: eq, value: foo }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested field 'discount_percent', visible_when.*references unknown field 'nonexistent_field'/)
      )
    end

    it "reports error for nested field condition with unknown operator" do
      v = with_metadata(
        models: [ order_model, line_item_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: item_type }
                    - field: discount_percent
                      visible_when: { field: item_type, operator: bad_op, value: foo }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested field 'discount_percent', visible_when.*uses unknown operator 'bad_op'/)
      )
    end

    it "validates disable_when conditions on nested fields" do
      v = with_metadata(
        models: [ order_model, line_item_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: item_type }
                    - field: notes
                      disable_when: { field: no_such_field, operator: eq, value: yes }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested field 'notes', disable_when.*references unknown field 'no_such_field'/)
      )
    end

    it "validates operator-type compatibility for nested field conditions" do
      v = with_metadata(
        models: [ order_model, line_item_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: item_type }
                    - field: notes
                      visible_when: { field: item_type, operator: gt, value: 5 }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/operator 'gt' is not compatible with field 'item_type'/)
      )
    end

    it "skips condition validation for service conditions in nested fields" do
      v = with_metadata(
        models: [ order_model, line_item_model ],
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Line Items"
                  type: nested_fields
                  association: line_items
                  fields:
                    - { field: item_type }
                    - field: notes
                      visible_when: { service: some_service }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("nested field 'notes'") }
      expect(condition_errors).to be_empty
    end
  end

  # --- JSON field section validations ---

  context "json_field sections" do
    let(:metadata_path) { "" }

    it "accepts valid json_field section" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: recipe
            fields:
              - { name: title, type: string }
              - { name: steps, type: json }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  fields:
                    - { field: instruction, type: string }
        YAML
      )

      result = v.validate
      json_errors = result.errors.select { |e| e.include?("json_field") }
      expect(json_errors).to be_empty
    end

    it "reports error when json_field does not exist on model" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: recipe
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: nonexistent
                  fields:
                    - { field: instruction }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/json_field 'nonexistent' does not exist on model 'recipe'/)
      )
    end

    it "reports error when json_field is not type json" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: recipe
            fields:
              - { name: title, type: string }
              - { name: steps, type: string }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  fields:
                    - { field: instruction }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/json_field 'steps' must be type 'json'/)
      )
    end

    it "reports error when both association and json_field are present" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: recipe
            fields:
              - { name: title, type: string }
              - { name: steps, type: json }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  association: some_assoc
                  fields:
                    - { field: instruction }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/cannot have both 'association' and 'json_field'/)
      )
    end

    it "validates target_model field references" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: recipe
              fields:
                - { name: title, type: string }
                - { name: steps, type: json }
          YAML
          <<~YAML
            model:
              name: step_definition
              table_name: _virtual
              fields:
                - { name: instruction, type: string }
                - { name: duration_minutes, type: integer }
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  target_model: step_definition
                  fields:
                    - { field: instruction }
                    - { field: nonexistent_field }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/field 'nonexistent_field' does not exist on target_model 'step_definition'/)
      )
    end

    it "reports error when target_model does not exist" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: recipe
            fields:
              - { name: title, type: string }
              - { name: steps, type: json }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  target_model: nonexistent_model
                  fields:
                    - { field: instruction }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/target_model 'nonexistent_model' does not exist/)
      )
    end
  end

  # --- Virtual model validations ---

  context "virtual models" do
    let(:metadata_path) { "" }

    it "warns when virtual model has associations" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: item_def
              table_name: _virtual
              fields:
                - { name: name, type: string }
              associations:
                - { name: category, type: belongs_to, target_model: category }
          YAML
          <<~YAML
            model:
              name: category
              fields:
                - { name: name, type: string }
              associations:
                - { name: item_defs, type: has_many, target_model: item_def }
          YAML
        ]
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/virtual model.*has associations.*will be ignored/)
      )
    end

    it "warns when virtual model has scopes" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item_def
            table_name: _virtual
            fields:
              - { name: name, type: string }
              - { name: active, type: boolean }
            scopes:
              - { name: active, where: { active: true } }
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/virtual model.*has scopes.*will be ignored/)
      )
    end

    it "does not warn for clean virtual model" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item_def
            table_name: _virtual
            fields:
              - { name: name, type: string }
              - { name: quantity, type: integer }
        YAML
      )

      result = v.validate
      virtual_warnings = result.warnings.select { |w| w.include?("virtual") }
      expect(virtual_warnings).to be_empty
    end

    it "warns when virtual model has model features enabled" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item_def
            table_name: _virtual
            fields:
              - { name: name, type: string }
            options:
              soft_delete: true
              auditing: true
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/model features.*soft_delete, auditing.*have no effect on virtual models/)
      )
    end
  end

  # --- Model option validations ---

  context "model options (soft_delete, auditing, userstamps, tree)" do
    let(:metadata_path) { "" }

    it "accepts soft_delete: true" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              soft_delete: true
        YAML
      )

      result = v.validate
      soft_delete_errors = result.errors.select { |e| e.include?("soft_delete") }
      expect(soft_delete_errors).to be_empty
    end

    it "accepts soft_delete with valid Hash" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              soft_delete:
                column: deleted_at
        YAML
      )

      result = v.validate
      soft_delete_errors = result.errors.select { |e| e.include?("soft_delete") }
      expect(soft_delete_errors).to be_empty
    end

    it "rejects soft_delete with invalid type" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              soft_delete: "yes"
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/soft_delete must be true or a Hash/)
      )
    end

    it "rejects soft_delete with unknown keys" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              soft_delete:
                column: deleted_at
                unknown_key: value
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/soft_delete has unknown keys: unknown_key/)
      )
    end

    it "rejects soft_delete.column that is not a string" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              soft_delete:
                column: 123
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/soft_delete.column must be a string/)
      )
    end

    it "accepts auditing: true" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              auditing: true
        YAML
      )

      result = v.validate
      auditing_errors = result.errors.select { |e| e.include?("auditing") }
      expect(auditing_errors).to be_empty
    end

    it "accepts auditing with only option" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
            options:
              auditing:
                only:
                  - title
                  - status
        YAML
      )

      result = v.validate
      auditing_errors = result.errors.select { |e| e.include?("auditing") }
      expect(auditing_errors).to be_empty
    end

    it "rejects auditing with both only and ignore" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              auditing:
                only:
                  - title
                ignore:
                  - status
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/auditing.only and auditing.ignore are mutually exclusive/)
      )
    end

    it "accepts userstamps: true" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              userstamps: true
        YAML
      )

      result = v.validate
      userstamps_errors = result.errors.select { |e| e.include?("userstamps") }
      expect(userstamps_errors).to be_empty
    end

    it "accepts userstamps with custom column names" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              userstamps:
                created_by: author_id
                updated_by: editor_id
        YAML
      )

      result = v.validate
      userstamps_errors = result.errors.select { |e| e.include?("userstamps") }
      expect(userstamps_errors).to be_empty
    end

    it "rejects userstamps with unknown keys" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              userstamps:
                destroyed_by: remover_id
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/userstamps has unknown keys: destroyed_by/)
      )
    end

    it "accepts userstamps with store_name option" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              userstamps:
                store_name: true
        YAML
      )

      result = v.validate
      userstamps_errors = result.errors.select { |e| e.include?("userstamps") }
      expect(userstamps_errors).to be_empty
    end

    it "errors when userstamps creator column conflicts with defined field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
              - { name: created_by_id, type: integer }
            options:
              userstamps: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/userstamps column 'created_by_id' conflicts/)
      )
    end

    it "errors when userstamps updater column conflicts with defined field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
              - { name: updated_by_id, type: integer }
            options:
              userstamps: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/userstamps column 'updated_by_id' conflicts/)
      )
    end

    it "errors when userstamps custom column conflicts with defined field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
              - { name: author_id, type: integer }
            options:
              userstamps:
                created_by: author_id
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/userstamps column 'author_id' conflicts/)
      )
    end

    it "errors when userstamps name column conflicts with defined field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
              - { name: created_by_name, type: string }
            options:
              userstamps:
                store_name: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/userstamps name column 'created_by_name' conflicts/)
      )
    end

    it "warns when userstamps enabled without timestamps" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              timestamps: false
              userstamps: true
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/userstamps enabled without timestamps/)
      )
    end

    it "does not warn about timestamps when timestamps are enabled" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: item
            fields:
              - { name: title, type: string }
            options:
              userstamps: true
        YAML
      )

      result = v.validate
      timestamp_warnings = result.warnings.select { |w| w.include?("userstamps enabled without timestamps") }
      expect(timestamp_warnings).to be_empty
    end

    it "accepts tree: true with parent_id field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            options:
              tree: true
        YAML
      )

      result = v.validate
      tree_errors = result.errors.select { |e| e.include?("tree") }
      expect(tree_errors).to be_empty
    end

    it "accepts tree with valid options" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_category_id, type: integer }
            options:
              tree:
                parent_field: parent_category_id
                children_name: subcategories
                parent_name: parent_category
        YAML
      )

      result = v.validate
      tree_errors = result.errors.select { |e| e.include?("tree") }
      expect(tree_errors).to be_empty
    end

    it "rejects tree with unknown keys" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            options:
              tree:
                order_column: position
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/tree has unknown keys: order_column/)
      )
    end

    it "errors when tree parent_field is not declared in fields" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
            options:
              tree: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/tree parent_field 'parent_id' must be declared in fields/)
      )
    end

    it "errors when tree parent_field is not integer type" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: string }
            options:
              tree: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/tree parent_field 'parent_id' must be type integer/)
      )
    end

    it "errors when tree dependent is invalid" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            options:
              tree:
                dependent: cascade
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/tree dependent 'cascade' is invalid/)
      )
    end

    it "errors when tree dependent: discard without soft_delete" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            options:
              tree:
                dependent: discard
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/dependent: discard requires soft_delete/)
      )
    end

    it "errors when tree ordered: true without position field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            options:
              tree:
                ordered: true
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/tree ordered: true requires position_field 'position'/)
      )
    end

    it "accepts tree ordered: true with position field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
              - { name: position, type: integer }
            options:
              tree:
                ordered: true
        YAML
      )

      result = v.validate
      tree_errors = result.errors.select { |e| e.include?("tree") }
      expect(tree_errors).to be_empty
    end

    it "warns on manual association conflict with tree" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            associations:
              - { type: belongs_to, name: parent, target_model: category }
            options:
              tree: true
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/manual belongs_to :parent association.*conflicts with tree/)
      )
    end

    it "accepts a model with all four features enabled" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: document
            fields:
              - { name: title, type: string }
              - { name: parent_id, type: integer }
            options:
              soft_delete: true
              auditing: true
              userstamps: true
              tree: true
        YAML
      )

      result = v.validate
      feature_errors = result.errors.select { |e|
        e.include?("soft_delete") || e.include?("auditing") ||
          e.include?("userstamps") || e.include?("tree")
      }
      expect(feature_errors).to be_empty
    end
  end

  # --- Tree-generated associations ---

  context "tree-generated associations" do
    let(:metadata_path) { "" }

    it "recognizes tree-generated children association in presenter validation" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            options:
              tree: true
        YAML
        presenters: [ <<~YAML ],
          presenter:
            name: category
            model: category
            show:
              layout:
                - section: Sub-Categories
                  type: association_list
                  association: children
                  display_template: "{name}"
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: category
            roles:
              admin:
                crud: [index, show, create, update, destroy]
                fields: { readable: all, writable: all }
                scope: all
        YAML
      )

      result = v.validate
      assoc_errors = result.errors.select { |e| e.include?("children") }
      expect(assoc_errors).to be_empty
    end

    it "recognizes tree-generated parent association in breadcrumb relation" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: category
            fields:
              - { name: name, type: string }
              - { name: parent_id, type: integer }
            options:
              tree: true
        YAML
        presenters: [ <<~YAML ],
          presenter:
            name: categories
            model: category
            slug: categories
        YAML
        permissions: [ <<~YAML ],
          permissions:
            model: category
            roles:
              admin:
                crud: [index, show, create, update, destroy]
                fields: { readable: all, writable: all }
                scope: all
        YAML
        view_groups: [ <<~YAML ]
          view_group:
            name: categories
            model: category
            primary: categories
            breadcrumb:
              relation: parent
            views:
              - page: categories
        YAML
      )

      result = v.validate
      breadcrumb_errors = result.errors.select { |e| e.include?("breadcrumb") }
      expect(breadcrumb_errors).to be_empty
    end
  end

  # --- label_method validations ---

  context "label_method" do
    let(:metadata_path) { "" }

    it "warns when label_method is not defined on a non-virtual model" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: task
            fields:
              - { name: title, type: string }
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(a_string_matching(/task.*no label_method defined/))
    end

    it "warns when label_method references a non-existent field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: task
            fields:
              - { name: title, type: string }
            options:
              label_method: nonexistent
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(a_string_matching(/task.*label_method 'nonexistent'.*not a defined field/))
    end

    it "does not warn when label_method references a valid field" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: task
            fields:
              - { name: title, type: string }
            options:
              label_method: title
        YAML
      )

      result = v.validate
      label_warnings = result.warnings.select { |w| w.include?("label_method") }
      expect(label_warnings).to be_empty
    end

    it "does not warn when label_method references a valid association" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: review
              fields:
                - { name: score, type: integer }
                - { name: employee_id, type: integer }
              associations:
                - type: belongs_to
                  name: employee
                  target_model: employee
                  foreign_key: employee_id
              options:
                label_method: employee
          YAML
          <<~YAML
            model:
              name: employee
              fields:
                - { name: name, type: string }
              options:
                label_method: name
          YAML
        ]
      )

      result = v.validate
      label_warnings = result.warnings.select { |w| w.include?("label_method") }
      expect(label_warnings).to be_empty
    end

    it "does not warn about label_method on virtual models" do
      v = with_metadata(
        models: [ <<~YAML ]
          model:
            name: dashboard
            table_name: _virtual
            fields:
              - { name: count, type: integer }
        YAML
      )

      result = v.validate
      label_warnings = result.warnings.select { |w| w.include?("label_method") }
      expect(label_warnings).to be_empty
    end
  end

  # --- Sub-section validations ---

  context "sub-sections" do
    let(:metadata_path) { "" }

    it "validates sub-section field references against target_model" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: contact
              fields:
                - { name: name, type: string }
                - { name: addresses, type: json }
          YAML
          <<~YAML
            model:
              name: address_def
              table_name: _virtual
              fields:
                - { name: street, type: string }
                - { name: city, type: string }
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: contact
            model: contact
            slug: contacts
            form:
              sections:
                - title: "Addresses"
                  type: nested_fields
                  json_field: addresses
                  target_model: address_def
                  sub_sections:
                    - title: "Location"
                      fields:
                        - { field: street }
                        - { field: nonexistent }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/field 'nonexistent' does not exist on target_model 'address_def'/)
      )
    end

    it "reports error when both fields and sub_sections present" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: contact
              fields:
                - { name: name, type: string }
                - { name: addresses, type: json }
          YAML
          <<~YAML
            model:
              name: address_def
              table_name: _virtual
              fields:
                - { name: street, type: string }
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: contact
            model: contact
            slug: contacts
            form:
              sections:
                - title: "Addresses"
                  type: nested_fields
                  json_field: addresses
                  target_model: address_def
                  fields:
                    - { field: street }
                  sub_sections:
                    - title: "Location"
                      fields:
                        - { field: street }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/cannot have both 'fields' and 'sub_sections'/)
      )
    end
  end

  # --- JSON field condition validations ---

  context "json_field conditions" do
    let(:metadata_path) { "" }

    it "validates json_field condition references against target_model fields" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: recipe
              fields:
                - { name: title, type: string }
                - { name: steps, type: json }
          YAML
          <<~YAML
            model:
              name: step_def
              table_name: _virtual
              fields:
                - { name: instruction, type: string }
                - { name: duration_minutes, type: integer }
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  target_model: step_def
                  fields:
                    - { field: instruction }
                    - field: duration_minutes
                      visible_when: { field: nonexistent_field, operator: eq, value: foo }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested field 'duration_minutes', visible_when.*references unknown field 'nonexistent_field'/)
      )
    end

    it "validates json_field condition operator" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: recipe
              fields:
                - { name: title, type: string }
                - { name: steps, type: json }
          YAML
          <<~YAML
            model:
              name: step_def
              table_name: _virtual
              fields:
                - { name: instruction, type: string }
                - { name: duration_minutes, type: integer }
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  target_model: step_def
                  fields:
                    - { field: instruction }
                    - field: duration_minutes
                      visible_when: { field: instruction, operator: bad_op, value: foo }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested field 'duration_minutes', visible_when.*uses unknown operator 'bad_op'/)
      )
    end

    it "accepts valid json_field conditions" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: recipe
              fields:
                - { name: title, type: string }
                - { name: steps, type: json }
          YAML
          <<~YAML
            model:
              name: step_def
              table_name: _virtual
              fields:
                - { name: instruction, type: string }
                - { name: duration_minutes, type: integer }
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  target_model: step_def
                  fields:
                    - { field: instruction }
                    - field: duration_minutes
                      visible_when: { field: instruction, operator: present }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("nested field") }
      expect(condition_errors).to be_empty
    end

    it "skips condition validation for json_field without target_model" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: recipe
            fields:
              - { name: title, type: string }
              - { name: steps, type: json }
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  fields:
                    - field: instruction
                      type: string
                      visible_when: { field: anything, operator: eq, value: foo }
        YAML
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("nested field") }
      expect(condition_errors).to be_empty
    end

    it "validates conditions in json_field sub_sections" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: recipe
              fields:
                - { name: title, type: string }
                - { name: steps, type: json }
          YAML
          <<~YAML
            model:
              name: step_def
              table_name: _virtual
              fields:
                - { name: instruction, type: string }
                - { name: notes, type: text }
          YAML
        ],
        presenters: [ <<~YAML ]
          presenter:
            name: recipe
            model: recipe
            slug: recipes
            form:
              sections:
                - title: "Steps"
                  type: nested_fields
                  json_field: steps
                  target_model: step_def
                  sub_sections:
                    - title: "Basic"
                      fields:
                        - { field: instruction }
                        - field: notes
                          disable_when: { field: bad_field, operator: eq, value: x }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/nested field 'notes', disable_when.*references unknown field 'bad_field'/)
      )
    end
  end

  # --- Parameterized scope parameter validations ---

  context "parameterized scope parameters" do
    let(:metadata_path) { "" }

    def model_with_parameterized_scope(parameters)
      <<~YAML
        model:
          name: product
          fields:
            - { name: name, type: string }
            - { name: price, type: float }
            - { name: status, type: enum, enum_values: [active, inactive] }
          scopes:
            - name: filtered
              type: parameterized
              parameters:
#{parameters.map { |p| "                - #{p}" }.join("\n")}
      YAML
    end

    def base_presenter
      <<~YAML
        presenter:
          name: products
          model: product
          slug: products
      YAML
    end

    def base_permission
      <<~YAML
        permissions:
          model: product
          roles:
            admin:
              crud: [index, show, create, update, destroy]
              fields: { readable: all, writable: all }
              scope: all
      YAML
    end

    it "accepts valid parameterized scope with all parameter types" do
      v = with_metadata(
        models: [ model_with_parameterized_scope([
          "{ name: min_price, type: float, required: true, min: 0 }",
          "{ name: category, type: enum, values: [a, b, c], default: a }",
          "{ name: active, type: boolean }",
          "{ name: search, type: string }"
        ]) ],
        presenters: [ base_presenter ],
        permissions: [ base_permission ]
      )

      result = v.validate
      param_errors = result.errors.select { |e| e.include?("parameterized") || e.include?("parameter") }
      expect(param_errors).to be_empty
    end

    it "reports error for invalid parameter type" do
      v = with_metadata(
        models: [ model_with_parameterized_scope([
          "{ name: amount, type: nonsense }"
        ]) ],
        presenters: [ base_presenter ],
        permissions: [ base_permission ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/parameter 'amount': invalid type 'nonsense'/)
      )
    end

    it "reports error for missing parameter name" do
      v = with_metadata(
        models: [ model_with_parameterized_scope([
          "{ type: integer }"
        ]) ],
        presenters: [ base_presenter ],
        permissions: [ base_permission ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/parameter is missing required 'name'/)
      )
    end

    it "reports error for duplicate parameter names" do
      v = with_metadata(
        models: [ model_with_parameterized_scope([
          "{ name: val, type: integer }",
          "{ name: val, type: float }"
        ]) ],
        presenters: [ base_presenter ],
        permissions: [ base_permission ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/duplicate parameter name 'val'/)
      )
    end

    it "reports error for enum parameter without values" do
      v = with_metadata(
        models: [ model_with_parameterized_scope([
          "{ name: category, type: enum }"
        ]) ],
        presenters: [ base_presenter ],
        permissions: [ base_permission ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/parameter 'category': enum type requires 'values' array/)
      )
    end

    it "reports error for model_select parameter without model" do
      v = with_metadata(
        models: [ model_with_parameterized_scope([
          "{ name: owner, type: model_select }"
        ]) ],
        presenters: [ base_presenter ],
        permissions: [ base_permission ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/parameter 'owner': model_select type requires 'model' reference/)
      )
    end

    it "reports error when min > max" do
      v = with_metadata(
        models: [ model_with_parameterized_scope([
          "{ name: amount, type: integer, min: 100, max: 10 }"
        ]) ],
        presenters: [ base_presenter ],
        permissions: [ base_permission ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/parameter 'amount': min \(100\) must be <= max \(10\)/)
      )
    end
  end

  # --- Advanced filter validations ---

  context "advanced filter validations" do
    let(:metadata_path) { "" }

    def model_yaml
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
            - { name: status, type: enum, enum_values: [open, closed] }
      YAML
    end

    def permission_yaml
      <<~YAML
        permissions:
          model: task
          roles:
            admin:
              crud: [index, show, create, update, destroy]
              fields: { readable: all, writable: all }
              scope: all
      YAML
    end

    it "reports error for non-positive max_conditions" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                max_conditions: 0
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/max_conditions must be a positive integer/)
      )
    end

    it "reports error for max_association_depth out of range" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                max_association_depth: 6
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/max_association_depth must be between 1 and 5/)
      )
    end

    it "reports error for max_nesting_depth out of range" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                max_nesting_depth: 11
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/max_nesting_depth must be between 1 and 10/)
      )
    end

    it "reports error for invalid default_combinator" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                default_combinator: xor
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/default_combinator must be 'and' or 'or'/)
      )
    end

    it "reports error for mutual exclusion of filterable_fields and filterable_fields_except" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                filterable_fields: [title]
                filterable_fields_except: [status]
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/filterable_fields and filterable_fields_except are mutually exclusive/)
      )
    end
  end

  # --- Saved filter validations ---

  context "saved filter validations" do
    let(:metadata_path) { "" }

    def model_yaml
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
      YAML
    end

    def permission_yaml
      <<~YAML
        permissions:
          model: task
          roles:
            admin:
              crud: [index, show, create, update, destroy]
              fields: { readable: all, writable: all }
              scope: all
      YAML
    end

    it "reports error for invalid visibility_option" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                saved_filters:
                  enabled: true
                  visibility_options: [personal, public]
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/invalid visibility_option 'public'/)
      )
    end

    it "reports error for invalid display mode" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                saved_filters:
                  enabled: true
                  display: modal
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/display must be one of: inline, dropdown, sidebar/)
      )
    end

    it "reports error for non-positive numeric limit" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                saved_filters:
                  enabled: true
                  max_per_user: -1
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/max_per_user must be a positive integer/)
      )
    end

    it "warns when saved_filter model is not defined" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ <<~YAML ],
          presenter:
            name: tasks
            model: task
            slug: tasks
            search:
              advanced_filter:
                enabled: true
                saved_filters:
                  enabled: true
        YAML
        permissions: [ permission_yaml ]
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/saved_filters.enabled is true but 'saved_filter' model is not defined/)
      )
    end
  end

  # --- Permission field_override role reference validations ---

  context "permission field_override role references" do
    let(:metadata_path) { "" }

    it "warns when field_override references unknown field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: employee
            fields:
              - { name: name, type: string }
              - { name: salary, type: decimal }
        YAML
        presenters: [ <<~YAML ],
          presenter:
            name: employees
            model: employee
            slug: employees
        YAML
        permissions: [ <<~YAML ]
          permissions:
            model: employee
            roles:
              admin:
                crud: [index, show, create, update, destroy]
                fields: { readable: all, writable: all }
                scope: all
            field_overrides:
              nonexistent_field:
                readable_by: [admin]
        YAML
      )

      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/field_override for unknown field 'nonexistent_field'/)
      )
    end
  end

  context "model aggregates" do
    let(:metadata_path) { "" }

    def project_with_issues(*aggregates_yaml)
      with_metadata(
        models: [
          <<~YAML,
            model:
              name: project
              fields:
                - { name: title, type: string }
              associations:
                - type: has_many
                  name: issues
                  target_model: issue
                  foreign_key: project_id
              aggregates:
                #{aggregates_yaml.join("\n                ")}
          YAML
          <<~YAML
            model:
              name: issue
              fields:
                - { name: title, type: string }
                - { name: priority, type: integer }
                - { name: status, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
          YAML
        ]
      )
    end

    it "accepts valid declarative count aggregate" do
      v = project_with_issues('issues_count: { function: count, association: issues }')
      result = v.validate
      agg_errors = result.errors.select { |e| e.include?("virtual column") }
      expect(agg_errors).to be_empty
    end

    it "accepts valid declarative sum aggregate with source_field" do
      v = project_with_issues('total_priority: { function: sum, association: issues, source_field: priority }')
      result = v.validate
      agg_errors = result.errors.select { |e| e.include?("virtual column") }
      expect(agg_errors).to be_empty
    end

    it "accepts valid declarative aggregate with where clause" do
      v = project_with_issues('open_issues: { function: count, association: issues, where: { status: open } }')
      result = v.validate
      agg_errors = result.errors.select { |e| e.include?("virtual column") }
      expect(agg_errors).to be_empty
    end

    it "errors when aggregate references unknown association" do
      v = project_with_issues('task_count: { function: count, association: tasks }')
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/virtual column 'task_count'.*unknown association 'tasks'/)
      )
    end

    it "errors when aggregate references belongs_to association" do
      v = with_metadata(
        models: [
          <<~YAML,
            model:
              name: issue
              fields:
                - { name: title, type: string }
              associations:
                - type: belongs_to
                  name: project
                  target_model: project
                  foreign_key: project_id
              aggregates:
                project_count: { function: count, association: project }
          YAML
          <<~YAML
            model:
              name: project
              fields:
                - { name: title, type: string }
          YAML
        ]
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/virtual column 'project_count'.*must be has_many, got 'belongs_to'/)
      )
    end

    it "raises MetadataError at parse time when non-count function missing source_field" do
      expect {
        project_with_issues('total: { function: sum, association: issues }')
      }.to raise_error(LcpRuby::MetadataError, /function 'sum' requires 'source_field'/)
    end

    it "errors when source_field not found on target model" do
      v = project_with_issues('total: { function: sum, association: issues, source_field: amount }')
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/virtual column 'total'.*source_field 'amount' not found on model 'issue'/)
      )
    end

    it "warns when where clause references unknown field on target model" do
      v = project_with_issues('filtered: { function: count, association: issues, where: { nonexistent: value } }')
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/virtual column 'filtered'.*where clause references field 'nonexistent' not found on model 'issue'/)
      )
    end

    it "does not warn when where clause references valid field" do
      v = project_with_issues('filtered: { function: count, association: issues, where: { status: open } }')
      result = v.validate
      where_warnings = result.warnings.select { |w| w.include?("where clause") }
      expect(where_warnings).to be_empty
    end

    it "raises MetadataError at parse time when aggregate name collides with field name" do
      expect {
        with_metadata(
          models: [
            <<~YAML,
              model:
                name: project
                fields:
                  - { name: title, type: string }
                associations:
                  - type: has_many
                    name: issues
                    target_model: issue
                    foreign_key: project_id
                aggregates:
                  title: { function: count, association: issues }
            YAML
            <<~YAML
              model:
                name: issue
                fields:
                  - { name: title, type: string }
                associations:
                  - type: belongs_to
                    name: project
                    target_model: project
                    foreign_key: project_id
            YAML
          ]
        )
      }.to raise_error(LcpRuby::MetadataError, /virtual column names collide with field names/)
    end

    it "raises MetadataError at parse time when SQL aggregate missing type" do
      expect {
        project_with_issues('custom: { sql: "SELECT 1" }')
      }.to raise_error(LcpRuby::MetadataError, /expression type requires 'type'/)
    end

    it "raises MetadataError at parse time when service aggregate missing type" do
      expect {
        project_with_issues('health: { service: project_health }')
      }.to raise_error(LcpRuby::MetadataError, /service type requires 'type'/)
    end

    it "accepts valid SQL aggregate with type" do
      v = project_with_issues('custom: { sql: "SELECT 1", type: integer }')
      result = v.validate
      agg_errors = result.errors.select { |e| e.include?("virtual column") }
      expect(agg_errors).to be_empty
    end

    it "accepts valid service aggregate with type" do
      v = project_with_issues('health: { service: project_health, type: string }')
      result = v.validate
      agg_errors = result.errors.select { |e| e.include?("virtual column") }
      expect(agg_errors).to be_empty
    end
  end

  describe "item_classes validation" do
    let(:metadata_path) { "" }

    it "passes for valid item_classes" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: title
                type: string
              - name: status
                type: enum
                enum_values: [open, done]
              - name: priority
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              table_columns:
                - { field: title }
                - { field: status }
              item_classes:
                - class: "lcp-row-muted"
                  when: { field: status, operator: eq, value: "done" }
                - class: "lcp-row-bold"
                  when: { field: priority, operator: eq, value: "high" }
        YAML
      )

      result = v.validate
      item_errors = result.errors.select { |e| e.include?("item_classes") }
      expect(item_errors).to be_empty
    end

    it "reports error for missing class" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: status
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - when: { field: status, operator: eq, value: "done" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes\[0\].*'class' must be a non-empty string/)
      )
    end

    it "reports error for empty class string" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: status
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - class: "  "
                  when: { field: status, operator: eq, value: "done" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes\[0\].*'class' must be a non-empty string/)
      )
    end

    it "reports error for class with invalid characters" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: status
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - class: 'lcp-row" onclick="alert(1)'
                  when: { field: status, operator: eq, value: "done" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes\[0\].*'class' contains invalid characters/)
      )
    end

    it "reports error for missing when" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: status
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - class: "lcp-row-danger"
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes\[0\].*'when' must be a condition hash/)
      )
    end

    it "reports error for unknown field in condition" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: title
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - class: "lcp-row-danger"
                  when: { field: nonexistent, operator: eq, value: "x" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes\[0\].*references unknown field 'nonexistent'/)
      )
    end

    it "reports error for invalid operator" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: status
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - class: "lcp-row-danger"
                  when: { field: status, operator: invalid_op, value: "x" }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes\[0\].*unknown operator 'invalid_op'/)
      )
    end

    it "reports error for operator-type incompatibility" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: title
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - class: "lcp-row-danger"
                  when: { field: title, operator: gt, value: 10 }
        YAML
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes\[0\].*operator 'gt' is not compatible with field 'title'/)
      )
    end

    it "passes for service condition" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - name: title
                type: string
        YAML
        presenters: [ <<~YAML ]
          presenter:
            name: tasks
            model: task
            slug: tasks
            index:
              item_classes:
                - class: "lcp-row-danger"
                  when: { service: overdue_checker }
        YAML
      )

      result = v.validate
      item_errors = result.errors.select { |e| e.include?("item_classes") }
      expect(item_errors).to be_empty
    end
  end

  # --- model_all_field_names includes FK, userstamp, aggregate, timestamp columns ---

  context "model_all_field_names" do
    let(:metadata_path) { "" }

    it "includes foreign key columns from belongs_to associations" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: company
            fields:
              - { name: name, type: string }
        YAML
          model:
            name: deal
            fields:
              - { name: title, type: string }
            associations:
              - { type: belongs_to, name: company, target_model: company, foreign_key: company_id }
        YAML2
        presenters: [ <<~YAML3 ],
          presenter:
            name: deal
            model: deal
            slug: deals
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML3
        permissions: [ <<~YAML4 ]
          permissions:
            model: deal
            roles:
              admin:
                crud: [index, show, create, update]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: fk_condition
                condition: { field: company_id, operator: present }
                effect:
                  deny_crud: [destroy]
        YAML4
      )

      result = v.validate
      fk_errors = result.errors.select { |e| e.include?("company_id") }
      expect(fk_errors).to be_empty
    end

    it "includes timestamp columns (created_at, updated_at, id)" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
            options:
              timestamps: true
        YAML
        presenters: [ <<~YAML2 ],
          presenter:
            name: task
            model: task
            slug: tasks
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML2
        permissions: [ <<~YAML3 ]
          permissions:
            model: task
            roles:
              admin:
                crud: [index, show, create, update]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: recent_only
                condition: { field: created_at, operator: gt, value: { date: today } }
                effect:
                  deny_crud: [destroy]
        YAML3
      )

      result = v.validate
      ts_errors = result.errors.select { |e| e.include?("created_at") }
      expect(ts_errors).to be_empty
    end

    it "includes userstamp columns when userstamps enabled" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
            options:
              timestamps: true
              userstamps: true
              userstamps_store_name: true
        YAML
        presenters: [ <<~YAML2 ],
          presenter:
            name: task
            model: task
            slug: tasks
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML2
        permissions: [ <<~YAML3 ]
          permissions:
            model: task
            roles:
              admin:
                crud: [index, show, create, update]
                fields: { readable: all, writable: all }
            default_role: admin
            record_rules:
              - name: owner_only
                condition: { field: created_by_id, operator: eq, value: { current_user: id } }
                effect:
                  deny_crud: [update, destroy]
        YAML3
      )

      result = v.validate
      userstamp_errors = result.errors.select { |e| e.include?("created_by_id") }
      expect(userstamp_errors).to be_empty
    end
  end

  # --- Compound condition validation ---

  context "compound condition validation" do
    let(:metadata_path) { "" }

    it "accepts valid compound 'all' condition in presenter" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
              - { name: priority, type: integer }
        YAML
        presenters: [ <<~YAML2 ]
          presenter:
            name: task
            model: task
            slug: tasks
            index:
              table_columns:
                - { field: title }
              item_classes:
                - class: "lcp-row-danger"
                  when:
                    all:
                      - { field: status, operator: not_eq, value: done }
                      - { field: priority, operator: gte, value: 80 }
        YAML2
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("item_classes") }
      expect(condition_errors).to be_empty
    end

    it "accepts valid compound 'any' condition in presenter" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
        YAML
        presenters: [ <<~YAML2 ]
          presenter:
            name: task
            model: task
            slug: tasks
            show:
              layout:
                - section: "Alert"
                  visible_when:
                    any:
                      - { field: status, operator: eq, value: urgent }
                      - { field: status, operator: eq, value: critical }
                  fields:
                    - { field: title }
        YAML2
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("visible_when") }
      expect(condition_errors).to be_empty
    end

    it "accepts valid 'not' condition" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
        YAML
        presenters: [ <<~YAML2 ]
          presenter:
            name: task
            model: task
            slug: tasks
            show:
              layout:
                - section: "Active"
                  visible_when:
                    not: { field: status, operator: eq, value: archived }
                  fields:
                    - { field: title }
        YAML2
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("visible_when") }
      expect(condition_errors).to be_empty
    end

    it "reports error for unknown field inside compound condition" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
        YAML
        presenters: [ <<~YAML2 ]
          presenter:
            name: task
            model: task
            slug: tasks
            index:
              table_columns:
                - { field: title }
              item_classes:
                - class: "lcp-row-danger"
                  when:
                    all:
                      - { field: status, operator: eq, value: active }
                      - { field: ghost_field, operator: eq, value: x }
        YAML2
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/item_classes.*references unknown field 'ghost_field'/)
      )
    end

    it "reports error for deeply nested unknown field" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
        YAML
        presenters: [ <<~YAML2 ]
          presenter:
            name: task
            model: task
            slug: tasks
            show:
              layout:
                - section: "Nested"
                  visible_when:
                    all:
                      - not: { field: nonexistent, operator: eq, value: x }
                  fields:
                    - { field: title }
        YAML2
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/references unknown field 'nonexistent'/)
      )
    end

    it "accepts compound record_rules in permissions" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
              - { name: priority, type: integer }
        YAML
        presenters: [ <<~YAML2 ],
          presenter:
            name: task
            model: task
            slug: tasks
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML2
        permissions: [ <<~YAML3 ]
          permissions:
            model: task
            roles:
              admin:
                crud: [index, show, create, update, destroy]
                fields: { readable: all, writable: all }
              editor:
                crud: [index, show, create, update]
                fields: { readable: all, writable: all }
            default_role: editor
            record_rules:
              - name: compound_lock
                condition:
                  all:
                    - { field: status, operator: eq, value: done }
                    - { field: priority, operator: gte, value: 80 }
                effect:
                  deny_crud: [update, destroy]
                  except_roles: [admin]
        YAML3
      )

      result = v.validate
      rule_errors = result.errors.select { |e| e.include?("record rule") }
      expect(rule_errors).to be_empty
    end
  end

  # --- Collection condition validation ---

  context "collection condition validation" do
    let(:metadata_path) { "" }

    it "accepts valid collection condition on action" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
            associations:
              - { type: has_many, name: comments, target_model: comment, foreign_key: task_id }
        YAML
          model:
            name: comment
            fields:
              - { name: body, type: text }
              - { name: approved, type: boolean }
            associations:
              - { type: belongs_to, name: task, target_model: task, foreign_key: task_id }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: task
            model: task
            slug: tasks
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
            actions:
              single:
                - name: publish
                  type: custom
                  visible_when:
                    collection: comments
                    quantifier: any
                    condition: { field: approved, operator: eq, value: true }
        YAML3
      )

      result = v.validate
      collection_errors = result.errors.select { |e| e.include?("collection") }
      expect(collection_errors).to be_empty
    end

    it "reports error for collection referencing unknown association" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
        YAML
        presenters: [ <<~YAML2 ]
          presenter:
            name: task
            model: task
            slug: tasks
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
            actions:
              single:
                - name: publish
                  type: custom
                  visible_when:
                    collection: nonexistent
                    quantifier: any
                    condition: { field: status, operator: eq, value: x }
        YAML2
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/collection 'nonexistent'.*not a defined association/)
      )
    end

    it "reports error for unknown field inside collection inner condition" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: task
            fields:
              - { name: title, type: string }
            associations:
              - { type: has_many, name: comments, target_model: comment, foreign_key: task_id }
        YAML
          model:
            name: comment
            fields:
              - { name: body, type: text }
            associations:
              - { type: belongs_to, name: task, target_model: task, foreign_key: task_id }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: task
            model: task
            slug: tasks
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
            actions:
              single:
                - name: publish
                  type: custom
                  visible_when:
                    collection: comments
                    quantifier: any
                    condition: { field: nonexistent_field, operator: eq, value: x }
        YAML3
      )

      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/collection.*references unknown field 'nonexistent_field'/)
      )
    end

    it "accepts collection condition nested inside compound condition" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
            associations:
              - { type: has_many, name: comments, target_model: comment, foreign_key: task_id }
        YAML
          model:
            name: comment
            fields:
              - { name: body, type: text }
              - { name: approved, type: boolean }
            associations:
              - { type: belongs_to, name: task, target_model: task, foreign_key: task_id }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: task
            model: task
            slug: tasks
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
            actions:
              single:
                - name: publish
                  type: custom
                  visible_when:
                    all:
                      - { field: status, operator: not_eq, value: done }
                      - collection: comments
                        quantifier: any
                        condition: { field: approved, operator: eq, value: true }
        YAML3
      )

      result = v.validate
      condition_errors = result.errors.select { |e| e.include?("publish") }
      expect(condition_errors).to be_empty
    end
  end

  # --- Lookup value reference validation ---

  describe "lookup value reference validation" do
    let(:metadata_path) { "" }

    def lookup_models
      [ <<~YAML, <<~YAML2 ]
        model:
          name: order
          fields:
            - { name: amount, type: float }
            - { name: tax_key, type: string }
      YAML
        model:
          name: tax_limit
          fields:
            - { name: key, type: string }
            - { name: threshold, type: float }
      YAML2
    end

    it "accepts valid lookup value reference" do
      v = with_metadata(
        models: lookup_models,
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: tax_limit
                      match: { key: vat_a }
                      pick: threshold
        YAML
      )
      result = v.validate
      lookup_errors = result.errors.select { |e| e.include?("lookup") }
      expect(lookup_errors).to be_empty
    end

    it "reports error for unknown lookup model" do
      v = with_metadata(
        models: lookup_models,
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: nonexistent
                      match: { key: vat_a }
                      pick: threshold
        YAML
      )
      result = v.validate
      expect(result.errors).to include(a_string_matching(/lookup references unknown model 'nonexistent'/))
    end

    it "reports error for unknown pick field" do
      v = with_metadata(
        models: lookup_models,
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: tax_limit
                      match: { key: vat_a }
                      pick: nonexistent
        YAML
      )
      result = v.validate
      expect(result.errors).to include(a_string_matching(/lookup 'pick' field 'nonexistent' does not exist/))
    end

    it "reports error for unknown match key" do
      v = with_metadata(
        models: lookup_models,
        presenters: [ <<~YAML ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: tax_limit
                      match: { nonexistent: vat_a }
                      pick: threshold
        YAML
      )
      result = v.validate
      expect(result.errors).to include(a_string_matching(/lookup 'match' key 'nonexistent' does not exist/))
    end

    it "reports error for nested lookup" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: order
            fields:
              - { name: amount, type: float }
        YAML
          model:
            name: tax_limit
            fields:
              - { name: key, type: string }
              - { name: threshold, type: float }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: tax_limit
                      match:
                        key:
                          lookup: tax_limit
                          match: { key: x }
                          pick: key
                      pick: threshold
        YAML3
      )
      result = v.validate
      expect(result.errors).to include(a_string_matching(/nested lookup.*not supported/))
    end

    it "validates dynamic match values (field_ref)" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: order
            fields:
              - { name: amount, type: float }
              - { name: tax_key, type: string }
        YAML
          model:
            name: tax_limit
            fields:
              - { name: key, type: string }
              - { name: threshold, type: float }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: tax_limit
                      match:
                        key:
                          field_ref: tax_key
                      pick: threshold
        YAML3
      )
      result = v.validate
      lookup_errors = result.errors.select { |e| e.include?("lookup") }
      expect(lookup_errors).to be_empty
    end

    it "reports error for dynamic match value referencing unknown field" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: order
            fields:
              - { name: amount, type: float }
        YAML
          model:
            name: tax_limit
            fields:
              - { name: key, type: string }
              - { name: threshold, type: float }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: tax_limit
                      match:
                        key:
                          field_ref: nonexistent_field
                      pick: threshold
        YAML3
      )
      result = v.validate
      expect(result.errors).to include(a_string_matching(/field_ref 'nonexistent_field'.*unknown field/))
    end

    it "reports error when match is not a hash" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: order
            fields:
              - { name: amount, type: float }
        YAML
          model:
            name: tax_limit
            fields:
              - { name: key, type: string }
              - { name: threshold, type: float }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: order
            model: order
            slug: orders
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
            actions:
              single:
                - name: check_tax
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      lookup: tax_limit
                      match: not_a_hash
                      pick: threshold
        YAML3
      )
      result = v.validate
      expect(result.errors).to include(a_string_matching(/lookup 'match' must be a hash/))
    end
  end

  # --- Eager loading validation for conditions ---

  describe "condition eager loading validation" do
    let(:metadata_path) { "" }

    it "warns when dot-path field in item_classes is not in includes" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: task
            fields:
              - { name: title, type: string }
            associations:
              - { type: belongs_to, name: company, target_model: company, foreign_key: company_id }
        YAML
          model:
            name: company
            fields:
              - { name: name, type: string }
              - { name: verified, type: boolean }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: task
            model: task
            slug: tasks
            index:
              table_columns: [title]
              item_classes:
                - class: verified-row
                  when: { field: "company.verified", operator: eq, value: true }
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML3
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/item_classes.*company.*includes/)
      )
    end

    it "warns when collection condition is not in includes" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: order
            fields:
              - { name: title, type: string }
            associations:
              - { type: has_many, name: approvals, target_model: approval, foreign_key: order_id }
        YAML
          model:
            name: approval
            fields:
              - { name: status, type: string }
            associations:
              - { type: belongs_to, name: order, target_model: order, foreign_key: order_id }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: order
            model: order
            slug: orders
            index:
              table_columns: [title]
              item_classes:
                - class: approved-row
                  when:
                    collection: approvals
                    quantifier: any
                    condition: { field: status, operator: eq, value: approved }
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML3
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/item_classes.*approvals.*includes/)
      )
    end

    it "warns when value field_ref dot-path is not in includes" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: task
            fields:
              - { name: amount, type: float }
            associations:
              - { type: belongs_to, name: company, target_model: company, foreign_key: company_id }
        YAML
          model:
            name: company
            fields:
              - { name: credit_limit, type: float }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: task
            model: task
            slug: tasks
            index:
              table_columns: [amount]
            actions:
              single:
                - name: approve
                  type: custom
                  visible_when:
                    field: amount
                    operator: lt
                    value:
                      field_ref: company.credit_limit
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: amount }
        YAML3
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/action.*approve.*company.*includes/)
      )
    end

    it "does not warn when includes cover condition refs" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: task
            fields:
              - { name: title, type: string }
            associations:
              - { type: belongs_to, name: company, target_model: company, foreign_key: company_id }
        YAML
          model:
            name: company
            fields:
              - { name: verified, type: boolean }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: task
            model: task
            slug: tasks
            index:
              table_columns: [title]
              includes: [company]
              item_classes:
                - class: verified-row
                  when: { field: "company.verified", operator: eq, value: true }
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML3
      )
      result = v.validate
      eager_warnings = result.warnings.select { |w| w.include?("includes") && w.include?("company") }
      expect(eager_warnings).to be_empty
    end

    it "does not warn for simple field conditions (no association)" do
      v = with_metadata(
        models: [ <<~YAML ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
        YAML
        presenters: [ <<~YAML2 ]
          presenter:
            name: task
            model: task
            slug: tasks
            index:
              table_columns: [title]
              item_classes:
                - class: active-row
                  when: { field: status, operator: eq, value: active }
            form:
              sections:
                - title: "Details"
                  fields:
                    - { field: title }
        YAML2
      )
      result = v.validate
      eager_warnings = result.warnings.select { |w| w.include?("includes") }
      expect(eager_warnings).to be_empty
    end

    it "does not warn for show/form conditions (only index)" do
      v = with_metadata(
        models: [ <<~YAML, <<~YAML2 ],
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
            associations:
              - { type: belongs_to, name: company, target_model: company, foreign_key: company_id }
        YAML
          model:
            name: company
            fields:
              - { name: verified, type: boolean }
        YAML2
        presenters: [ <<~YAML3 ]
          presenter:
            name: task
            model: task
            slug: tasks
            index:
              table_columns: [title]
            form:
              sections:
                - title: "Details"
                  fields:
                    - field: title
                      visible_when: { field: "company.verified", operator: eq, value: true }
        YAML3
      )
      result = v.validate
      eager_warnings = result.warnings.select { |w| w.include?("N+1") || (w.include?("includes") && w.include?("company.verified")) }
      expect(eager_warnings).to be_empty
    end
  end

  # --- Page / Zone / Widget / Dialog validations ---

  context "page validations" do
    let(:metadata_path) { "" }

    let(:base_model_yaml) do
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
            - { name: amount, type: decimal }
          scopes:
            - { name: recent, order: { created_at: desc }, limit: 10 }
            - { name: active, where: { status: active } }
      YAML
    end

    let(:base_presenter_yaml) do
      <<~YAML
        presenter:
          name: tasks
          model: task
          slug: tasks
      YAML
    end

    it "accepts a valid dashboard page with all zone types" do
      v = with_metadata(
        models: [ base_model_yaml ],
        presenters: [ base_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: dashboard
            slug: dashboard
            layout: grid
            zones:
              - name: task_count
                type: widget
                widget:
                  type: kpi_card
                  model: task
                  aggregate: count
                  icon: check
                position: { row: 1, col: 1, width: 4, height: 1 }
              - name: welcome
                type: widget
                widget:
                  type: text
                  content_key: welcome
                position: { row: 1, col: 5, width: 8, height: 1 }
              - name: recent_tasks
                presenter: tasks
                scope: recent
                limit: 5
                position: { row: 2, col: 1, width: 12, height: 2 }
        YAML
      )
      result = v.validate
      page_errors = result.errors.select { |e| e.include?("Page") || e.include?("page") }
      expect(page_errors).to be_empty
    end

    it "reports error when page references unknown model" do
      v = with_metadata(
        models: [ base_model_yaml ],
        presenters: [ base_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: bad_page
            model: nonexistent
            zones:
              - name: main
                presenter: tasks
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/Page 'bad_page': references unknown model 'nonexistent'/)
      )
    end

    it "reports error when presenter zone references unknown presenter" do
      v = with_metadata(
        models: [ base_model_yaml ],
        presenters: [ base_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: bad_page
            zones:
              - name: main
                presenter: ghost_presenter
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/references unknown presenter 'ghost_presenter'/)
      )
    end

    it "reports error when kpi_card widget references unknown model" do
      v = with_metadata(
        models: [ base_model_yaml ],
        presenters: [ base_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: bad_page
            zones:
              - name: count
                type: widget
                widget:
                  type: kpi_card
                  model: nonexistent
                  aggregate: count
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/widget references unknown model 'nonexistent'/)
      )
    end

    it "reports error when list widget references unknown model" do
      v = with_metadata(
        models: [ base_model_yaml ],
        presenters: [ base_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: bad_page
            zones:
              - name: items
                type: widget
                widget:
                  type: list
                  model: nonexistent
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/widget references unknown model 'nonexistent'/)
      )
    end

    it "warns when grid page zones have no position" do
      v = with_metadata(
        models: [ base_model_yaml ],
        presenters: [ base_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: grid_page
            layout: grid
            zones:
              - name: main
                presenter: tasks
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/grid layout but zones.*main.*have no position/)
      )
    end
  end

  context "zone scope validations" do
    let(:metadata_path) { "" }

    let(:model_yaml) do
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
          scopes:
            - { name: recent, order: { created_at: desc }, limit: 10 }
      YAML
    end

    let(:presenter_yaml) do
      <<~YAML
        presenter:
          name: tasks
          model: task
          slug: tasks
      YAML
    end

    it "reports error when presenter zone scope does not exist on model" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: main
                presenter: tasks
                scope: nonexistent_scope
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/scope 'nonexistent_scope' does not exist on model 'task'/)
      )
    end

    it "reports error when widget zone scope does not exist on model" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: count
                type: widget
                widget:
                  type: kpi_card
                  model: task
                  aggregate: count
                scope: nonexistent_scope
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/scope 'nonexistent_scope' does not exist on model 'task'/)
      )
    end

    it "warns when text widget has scope" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: welcome
                type: widget
                widget:
                  type: text
                  content_key: welcome
                scope: recent
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/text widget has scope but no model context/)
      )
    end

    it "accepts valid scope" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: main
                presenter: tasks
                scope: recent
        YAML
      )
      result = v.validate
      scope_errors = result.errors.select { |e| e.include?("scope") }
      expect(scope_errors).to be_empty
    end
  end

  context "zone scope_context validations" do
    let(:metadata_path) { "" }

    let(:employee_model_yaml) do
      <<~YAML
        model:
          name: employee
          fields:
            - { name: name, type: string }
            - { name: department_id, type: integer }
      YAML
    end

    let(:leave_model_yaml) do
      <<~YAML
        model:
          name: leave_request
          fields:
            - { name: employee_id, type: integer }
            - { name: status, type: string }
      YAML
    end

    let(:employee_presenter_yaml) do
      <<~YAML
        presenter:
          name: employee_show
          model: employee
          slug: employees
      YAML
    end

    let(:leave_presenter_yaml) do
      <<~YAML
        presenter:
          name: leave_requests_index
          model: leave_request
          slug: leave-requests
      YAML
    end

    it "accepts valid scope_context with :record_id reference" do
      v = with_metadata(
        models: [ employee_model_yaml, leave_model_yaml ],
        presenters: [ employee_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leave_requests_index
                area: tabs
                label_key: tabs.leaves
                scope_context:
                  employee_id: ":record_id"
        YAML
      )
      result = v.validate
      sc_warnings = result.warnings.select { |w| w.include?("scope_context") }
      expect(sc_warnings).to be_empty
    end

    it "warns when scope_context key is not a field on zone model" do
      v = with_metadata(
        models: [ employee_model_yaml, leave_model_yaml ],
        presenters: [ employee_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leave_requests_index
                area: tabs
                scope_context:
                  nonexistent_field: ":record_id"
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/scope_context key 'nonexistent_field' is not a known field/)
      )
    end

    it "warns when scope_context has unrecognized dynamic reference" do
      v = with_metadata(
        models: [ employee_model_yaml, leave_model_yaml ],
        presenters: [ employee_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leave_requests_index
                area: tabs
                scope_context:
                  employee_id: ":unknown_ref"
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/scope_context value ':unknown_ref' is not a recognized dynamic reference/)
      )
    end

    it "warns when :record.<field> references unknown field on page model" do
      v = with_metadata(
        models: [ employee_model_yaml, leave_model_yaml ],
        presenters: [ employee_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leave_requests_index
                area: tabs
                scope_context:
                  employee_id: ":record.nonexistent_field"
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/field 'nonexistent_field' not found on page model 'employee'/)
      )
    end

    it "accepts :current_user_id and :current_year references" do
      v = with_metadata(
        models: [ employee_model_yaml, leave_model_yaml ],
        presenters: [ employee_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leave_requests_index
                area: tabs
                scope_context:
                  employee_id: ":current_user_id"
        YAML
      )
      result = v.validate
      sc_warnings = result.warnings.select { |w| w.include?("scope_context") && w.include?("not a recognized") }
      expect(sc_warnings).to be_empty
    end
  end

  context "tab zone label_key warnings" do
    let(:metadata_path) { "" }

    let(:model_yaml) do
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
      YAML
    end

    let(:presenter_yaml) do
      <<~YAML
        presenter:
          name: tasks
          model: task
          slug: tasks
      YAML
    end

    it "warns when tab zone has no label_key" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: detail
            model: task
            zones:
              - name: header
                presenter: tasks
                area: main
              - name: tab1
                presenter: tasks
                area: tabs
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/tab zone has no label_key/)
      )
    end

    it "does not warn when tab zone has label_key" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: detail
            model: task
            zones:
              - name: header
                presenter: tasks
                area: main
              - name: tab1
                presenter: tasks
                area: tabs
                label_key: my.tab
        YAML
      )
      result = v.validate
      tab_warnings = result.warnings.select { |w| w.include?("label_key") }
      expect(tab_warnings).to be_empty
    end
  end

  context "zone visible_when validations" do
    let(:metadata_path) { "" }

    let(:model_yaml) do
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
            - { name: status, type: string }
      YAML
    end

    let(:presenter_yaml) do
      <<~YAML
        presenter:
          name: tasks
          model: task
          slug: tasks
      YAML
    end

    it "accepts visible_when with role string" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: main
                presenter: tasks
                visible_when:
                  role: admin
        YAML
      )
      result = v.validate
      vw_errors = result.errors.select { |e| e.include?("visible_when") }
      expect(vw_errors).to be_empty
    end

    it "accepts visible_when with role array" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: main
                presenter: tasks
                visible_when:
                  role:
                    - admin
                    - manager
        YAML
      )
      result = v.validate
      vw_errors = result.errors.select { |e| e.include?("visible_when") }
      expect(vw_errors).to be_empty
    end

    it "reports error when visible_when role is not string" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: main
                presenter: tasks
                visible_when:
                  role: 123
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/visible_when role must be a string/)
      )
    end

    it "accepts visible_when with valid field condition" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: main
                presenter: tasks
                visible_when:
                  field: status
                  operator: eq
                  value: active
        YAML
      )
      result = v.validate
      vw_errors = result.errors.select { |e| e.include?("visible_when") }
      expect(vw_errors).to be_empty
    end

    it "reports error when visible_when references unknown field" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: main
                presenter: tasks
                visible_when:
                  field: nonexistent_field
                  operator: eq
                  value: true
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/visible_when.*references unknown field 'nonexistent_field'/)
      )
    end

    it "warns when visible_when condition has no model context" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: welcome
                type: widget
                widget:
                  type: text
                  content_key: welcome
                visible_when:
                  field: status
                  operator: eq
                  value: active
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/visible_when condition has no model context/)
      )
    end
  end

  context "widget field validations" do
    let(:metadata_path) { "" }

    let(:model_yaml) do
      <<~YAML
        model:
          name: order
          fields:
            - { name: title, type: string }
            - { name: total_amount, type: decimal }
      YAML
    end

    let(:presenter_yaml) do
      <<~YAML
        presenter:
          name: orders
          model: order
          slug: orders
      YAML
    end

    it "reports error when aggregate_field references unknown field" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: total
                type: widget
                widget:
                  type: kpi_card
                  model: order
                  aggregate: sum
                  aggregate_field: nonexistent_field
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/aggregate_field 'nonexistent_field' does not exist on model 'order'/)
      )
    end

    it "accepts valid aggregate_field" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: total
                type: widget
                widget:
                  type: kpi_card
                  model: order
                  aggregate: sum
                  aggregate_field: total_amount
        YAML
      )
      result = v.validate
      agg_errors = result.errors.select { |e| e.include?("aggregate_field") }
      expect(agg_errors).to be_empty
    end

    it "warns when aggregate sum/avg/min/max used without aggregate_field" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            zones:
              - name: total
                type: widget
                widget:
                  type: kpi_card
                  model: order
                  aggregate: sum
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/kpi_card uses 'sum' without aggregate_field/)
      )
    end

    it "warns when link_to references unknown slug" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            slug: test
            zones:
              - name: total
                type: widget
                widget:
                  type: kpi_card
                  model: order
                  aggregate: count
                  link_to: unknown-slug
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/link_to 'unknown-slug' does not match any known page slug/)
      )
    end

    it "does not warn when link_to references valid slug" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            slug: orders
            zones:
              - name: total
                type: widget
                widget:
                  type: kpi_card
                  model: order
                  aggregate: count
                  link_to: orders
        YAML
      )
      result = v.validate
      link_warnings = result.warnings.select { |w| w.include?("link_to") }
      expect(link_warnings).to be_empty
    end
  end

  context "composite page main zone index constraint" do
    let(:metadata_path) { "" }

    let(:model_yaml) do
      <<~YAML
        model:
          name: employee
          fields:
            - { name: name, type: string }
      YAML
    end

    let(:leave_model_yaml) do
      <<~YAML
        model:
          name: leave_request
          fields:
            - { name: employee_id, type: integer }
            - { name: reason, type: string }
      YAML
    end

    let(:show_presenter_yaml) do
      <<~YAML
        presenter:
          name: employee_show
          model: employee
          slug: employees
          show:
            layout:
              - section: Details
                fields:
                  - { field: name }
      YAML
    end

    let(:index_presenter_yaml) do
      <<~YAML
        presenter:
          name: employee_index
          model: employee
          slug: emp-index
          index:
            table_columns:
              - { field: name }
      YAML
    end

    let(:leave_presenter_yaml) do
      <<~YAML
        presenter:
          name: leaves_index
          model: leave_request
          slug: leaves
          index:
            table_columns:
              - { field: reason }
      YAML
    end

    it "errors when main zone is an index presenter and page has tabs" do
      v = with_metadata(
        models: [ model_yaml, leave_model_yaml ],
        presenters: [ index_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_index
                area: main
              - name: leaves
                presenter: leaves_index
                area: tabs
                label_key: tabs.leaves
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/main zone presenter 'employee_index' is an index-only presenter.*tab zones/)
      )
    end

    it "does not error when main zone is a show presenter with tabs" do
      v = with_metadata(
        models: [ model_yaml, leave_model_yaml ],
        presenters: [ show_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leaves_index
                area: tabs
                label_key: tabs.leaves
        YAML
      )
      result = v.validate
      main_errors = result.errors.select { |e| e.include?("index presenter") }
      expect(main_errors).to be_empty
    end

    it "does not error when main zone presenter has both index and show with tabs" do
      full_presenter_yaml = <<~YAML
        presenter:
          name: employee_full
          model: employee
          slug: emp-full
          index:
            table_columns:
              - { field: name }
          show:
            layout:
              - section: Details
                fields:
                  - { field: name }
      YAML
      v = with_metadata(
        models: [ model_yaml, leave_model_yaml ],
        presenters: [ full_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_full
                area: main
              - name: leaves
                presenter: leaves_index
                area: tabs
                label_key: tabs.leaves
        YAML
      )
      result = v.validate
      main_errors = result.errors.select { |e| e.include?("index-only presenter") }
      expect(main_errors).to be_empty
    end

    it "does not error when main zone is index but no tabs" do
      v = with_metadata(
        models: [ model_yaml, leave_model_yaml ],
        presenters: [ index_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_index
                area: main
              - name: leaves
                presenter: leaves_index
                area: below
        YAML
      )
      result = v.validate
      main_errors = result.errors.select { |e| e.include?("index presenter") }
      expect(main_errors).to be_empty
    end

    it "warns when main zone presenter model does not match page model" do
      v = with_metadata(
        models: [ model_yaml, leave_model_yaml ],
        presenters: [ show_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: leave_request
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leaves_index
                area: tabs
                label_key: tabs.leaves
        YAML
      )
      result = v.validate
      expect(result.warnings).to include(
        a_string_matching(/main zone presenter 'employee_show' uses model 'employee' but page model is 'leave_request'/)
      )
    end

    it "does not warn when main zone presenter model matches page model" do
      v = with_metadata(
        models: [ model_yaml, leave_model_yaml ],
        presenters: [ show_presenter_yaml, leave_presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: emp_detail
            model: employee
            zones:
              - name: header
                presenter: employee_show
                area: main
              - name: leaves
                presenter: leaves_index
                area: tabs
                label_key: tabs.leaves
        YAML
      )
      result = v.validate
      model_warnings = result.warnings.select { |w| w.include?("page model is") }
      expect(model_warnings).to be_empty
    end
  end

  context "zone limit and position validations" do
    let(:metadata_path) { "" }

    let(:model_yaml) do
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
      YAML
    end

    let(:presenter_yaml) do
      <<~YAML
        presenter:
          name: tasks
          model: task
          slug: tasks
      YAML
    end

    it "reports error when position has row: 0" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_page
            layout: grid
            zones:
              - name: main
                presenter: tasks
                position: { row: 0, col: 1, width: 12, height: 1 }
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/position row must be a positive integer/)
      )
    end
  end

  context "dialog config validations" do
    let(:metadata_path) { "" }

    let(:model_yaml) do
      <<~YAML
        model:
          name: task
          fields:
            - { name: title, type: string }
      YAML
    end

    let(:presenter_yaml) do
      <<~YAML
        presenter:
          name: tasks
          model: task
          slug: tasks
      YAML
    end

    it "reports error when dialog size is invalid" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_dialog
            dialog:
              size: huge
            zones:
              - name: main
                presenter: tasks
        YAML
      )
      result = v.validate
      expect(result.errors).to include(
        a_string_matching(/dialog size 'huge' is invalid/)
      )
    end

    it "accepts valid dialog config" do
      v = with_metadata(
        models: [ model_yaml ],
        presenters: [ presenter_yaml ],
        pages: [ <<~YAML ]
          page:
            name: test_dialog
            dialog:
              size: large
              closable: false
              title_key: lcp_ruby.dialogs.test
            zones:
              - name: main
                presenter: tasks
        YAML
      )
      result = v.validate
      dialog_errors = result.errors.select { |e| e.include?("dialog") }
      expect(dialog_errors).to be_empty
    end
  end
end

RSpec.describe LcpRuby::Metadata::ConfigurationValidator::ValidationResult do
  it "is valid when no errors" do
    result = described_class.new(errors: [], warnings: [ "some warning" ])
    expect(result).to be_valid
  end

  it "is not valid when errors exist" do
    result = described_class.new(errors: [ "some error" ], warnings: [])
    expect(result).not_to be_valid
  end

  it "formats output with errors and warnings" do
    result = described_class.new(errors: [ "err1" ], warnings: [ "warn1" ])
    output = result.to_s
    expect(output).to include("[ERROR] err1")
    expect(output).to include("[WARN]  warn1")
  end

  it "shows success message when valid" do
    result = described_class.new(errors: [], warnings: [])
    expect(result.to_s).to include("Configuration is valid.")
  end
end

RSpec.describe "ConfigurationValidator virtual column validations" do
  def create_metadata(models: [], presenters: [], permissions: [], view_groups: [], menu: nil)
    dir = Dir.mktmpdir("lcp_vc_test")
    %w[models presenters permissions views].each { |d| FileUtils.mkdir_p(File.join(dir, d)) }

    models.each_with_index do |yaml, i|
      File.write(File.join(dir, "models", "model_#{i}.yml"), yaml)
    end
    presenters.each_with_index do |yaml, i|
      File.write(File.join(dir, "presenters", "presenter_#{i}.yml"), yaml)
    end
    permissions.each_with_index do |yaml, i|
      File.write(File.join(dir, "permissions", "perm_#{i}.yml"), yaml)
    end
    view_groups.each_with_index do |yaml, i|
      File.write(File.join(dir, "views", "vg_#{i}.yml"), yaml)
    end
    File.write(File.join(dir, "menu.yml"), menu) if menu

    dir
  end

  after do
    FileUtils.rm_rf(@tmpdir) if @tmpdir
  end

  def with_metadata(**opts)
    @tmpdir = create_metadata(**opts)
    loader = LcpRuby::Metadata::Loader.new(@tmpdir)
    loader.load_all
    LcpRuby::Metadata::ConfigurationValidator.new(loader)
  end

  it "errors when VC name collides with association name" do
    v = with_metadata(
      models: [
        <<~YAML,
          model:
            name: item
            fields:
              - { name: title, type: string }
              - { name: project_id, type: integer }
        YAML
        <<~YAML
          model:
            name: project
            fields:
              - { name: title, type: string }
            associations:
              - { type: has_many, name: items, target_model: item, foreign_key: project_id }
            virtual_columns:
              items:
                function: count
                association: items
        YAML
      ]
    )

    result = v.validate
    expect(result.errors).to include(a_string_matching(/collides with association 'items'/))
  end

  it "errors when VC name collides with scope name" do
    v = with_metadata(
      models: [ <<~YAML ]
        model:
          name: task
          fields:
            - { name: title, type: string }
            - { name: status, type: string }
          scopes:
            - { name: active, where: { status: active } }
          virtual_columns:
            active:
              expression: "1"
              type: boolean
      YAML
    )

    result = v.validate
    expect(result.errors).to include(a_string_matching(/collides with scope 'active'/))
  end

  it "errors when VC name is a reserved method" do
    v = with_metadata(
      models: [ <<~YAML ]
        model:
          name: thing
          fields:
            - { name: title, type: string }
          virtual_columns:
            reload:
              expression: "1"
              type: integer
      YAML
    )

    result = v.validate
    expect(result.errors).to include(a_string_matching(/collides with reserved method 'reload'/))
  end

  it "warns on multiple join+group virtual columns (cartesian risk)" do
    v = with_metadata(
      models: [
        <<~YAML,
          model:
            name: li
            fields:
              - { name: qty, type: integer }
              - { name: order_id, type: integer }
        YAML
        <<~YAML,
          model:
            name: payment
            fields:
              - { name: amount, type: decimal }
              - { name: order_id, type: integer }
        YAML
        <<~YAML
          model:
            name: order
            fields:
              - { name: title, type: string }
            virtual_columns:
              total_qty:
                expression: "SUM(lis.qty)"
                join: "LEFT JOIN lis ON lis.order_id = %{table}.id"
                group: true
                type: integer
              total_amount:
                expression: "SUM(payments.amount)"
                join: "LEFT JOIN payments ON payments.order_id = %{table}.id"
                group: true
                type: decimal
        YAML
      ]
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/cartesian product risk/))
  end

  it "warns on group+window function combination" do
    v = with_metadata(
      models: [ <<~YAML ]
        model:
          name: deal
          fields:
            - { name: title, type: string }
            - { name: category_id, type: integer }
          virtual_columns:
            total_grouped:
              expression: "SUM(1)"
              join: "LEFT JOIN line_items ON line_items.deal_id = %{table}.id"
              group: true
              type: integer
            category_rank:
              expression: "ROW_NUMBER() OVER(PARTITION BY %{table}.category_id ORDER BY %{table}.id)"
              type: integer
      YAML
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/window function/))
  end

  it "warns on auto_include with join" do
    v = with_metadata(
      models: [ <<~YAML ]
        model:
          name: project
          fields:
            - { name: title, type: string }
          virtual_columns:
            company_name:
              expression: "companies.name"
              join: "LEFT JOIN companies ON companies.id = 1"
              type: string
              auto_include: true
      YAML
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/auto_include with join/))
  end

  it "warns on auto_include with service-only VC" do
    svc = double("vc_service")
    allow(svc).to receive(:respond_to?).with(:sql_expression).and_return(false)
    LcpRuby::Services::Registry.register("virtual_columns", "no_sql_svc", svc)

    v = with_metadata(
      models: [ <<~YAML ]
        model:
          name: project
          fields:
            - { name: title, type: string }
          virtual_columns:
            health:
              service: no_sql_svc
              type: integer
              auto_include: true
      YAML
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/auto_include with service-only VC/))
  end

  it "warns when service-only VC is in table_columns" do
    svc = double("vc_service")
    allow(svc).to receive(:respond_to?).with(:sql_expression).and_return(false)
    LcpRuby::Services::Registry.register("virtual_columns", "no_sql_svc2", svc)

    v = with_metadata(
      models: [ <<~YAML ],
        model:
          name: invoice
          fields:
            - { name: title, type: string }
          virtual_columns:
            health:
              service: no_sql_svc2
              type: integer
      YAML
      presenters: [ <<~YAML ],
        presenter:
          name: invoices
          model: invoice
          slug: invoices
          index:
            table_columns:
              - { field: title }
              - { field: health }
      YAML
      permissions: [ <<~YAML ]
        permissions:
          model: invoice
          roles:
            admin:
              crud: [create, read, update, delete]
      YAML
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/service-only.*nil on index pages/))
  end

  it "warns when service-only VC is in tile fields" do
    svc = double("vc_service")
    allow(svc).to receive(:respond_to?).with(:sql_expression).and_return(false)
    LcpRuby::Services::Registry.register("virtual_columns", "no_sql_tile", svc)

    v = with_metadata(
      models: [ <<~YAML ],
        model:
          name: widget
          fields:
            - { name: title, type: string }
          virtual_columns:
            score:
              service: no_sql_tile
              type: integer
      YAML
      presenters: [ <<~YAML ],
        presenter:
          name: widgets
          model: widget
          slug: widgets
          index:
            layout: tiles
            tile:
              title_field: title
              fields:
                - { field: score }
      YAML
      permissions: [ <<~YAML ]
        permissions:
          model: widget
          roles:
            admin:
              crud: [create, read, update, delete]
      YAML
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/service-only.*nil on index pages/))
  end

  it "raises at parse time when VC name collides with field name" do
    # Field name collision is caught by ModelDefinition.validate! at parse time,
    # before the ConfigurationValidator even runs.
    expect {
      with_metadata(
        models: [ <<~YAML ]
          model:
            name: task
            fields:
              - { name: title, type: string }
              - { name: status, type: string }
            virtual_columns:
              status:
                expression: "1"
                type: integer
        YAML
      )
    }.to raise_error(LcpRuby::MetadataError, /virtual column names collide with field names: status/)
  end

  it "warns when service-only VC is in item_classes condition" do
    svc = double("vc_service")
    allow(svc).to receive(:respond_to?).with(:sql_expression).and_return(false)
    LcpRuby::Services::Registry.register("virtual_columns", "no_sql_ic", svc)

    v = with_metadata(
      models: [ <<~YAML ],
        model:
          name: ticket
          fields:
            - { name: title, type: string }
          virtual_columns:
            urgency:
              service: no_sql_ic
              type: integer
      YAML
      presenters: [ <<~YAML ],
        presenter:
          name: tickets
          model: ticket
          slug: tickets
          index:
            table_columns:
              - { field: title }
            item_classes:
              - class: lcp-row-danger
                when: { field: urgency, operator: gt, value: "5" }
      YAML
      permissions: [ <<~YAML ]
        permissions:
          model: ticket
          roles:
            admin:
              crud: [create, read, update, delete]
      YAML
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/item_classes.*service-only.*nil on index pages/))
  end

  it "warns when service-only VC is in compound item_classes condition" do
    svc = double("vc_service")
    allow(svc).to receive(:respond_to?).with(:sql_expression).and_return(false)
    LcpRuby::Services::Registry.register("virtual_columns", "no_sql_cmp", svc)

    v = with_metadata(
      models: [ <<~YAML ],
        model:
          name: alert
          fields:
            - { name: title, type: string }
          virtual_columns:
            severity:
              service: no_sql_cmp
              type: integer
      YAML
      presenters: [ <<~YAML ],
        presenter:
          name: alerts
          model: alert
          slug: alerts
          index:
            table_columns:
              - { field: title }
            item_classes:
              - class: lcp-row-warning
                when:
                  any:
                    - { field: severity, operator: gt, value: "3" }
                    - { field: title, operator: present }
      YAML
      permissions: [ <<~YAML ]
        permissions:
          model: alert
          roles:
            admin:
              crud: [create, read, update, delete]
      YAML
    )

    result = v.validate
    expect(result.warnings).to include(a_string_matching(/item_classes.*service-only.*nil on index pages/))
  end
end
