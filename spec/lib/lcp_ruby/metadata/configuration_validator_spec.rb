require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe LcpRuby::Metadata::ConfigurationValidator do
  let(:loader) { LcpRuby::Metadata::Loader.new(metadata_path) }
  let(:validator) { described_class.new(loader) }

  before { loader.load_all }

  # Helper to create a temporary metadata directory with YAML files
  def create_metadata(models: [], presenters: [], permissions: [], view_groups: [], menu: nil)
    dir = Dir.mktmpdir("lcp_test")
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
        a_string_matching(/condition references unknown field 'ghost_field'/)
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
                - presenter: project
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown model/)
    end
  end

  context "view group references unknown presenter" do
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
                - presenter: project
                - presenter: ghost_presenter
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /unknown presenter/)
    end
  end

  context "presenter in multiple view groups" do
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
                  - presenter: project
            YAML
            <<~YAML
              view_group:
                name: group_b
                model: project
                primary: project_public
                views:
                  - presenter: project_public
                  - presenter: project
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
                - presenter: project
          YAML
        )
      }.to raise_error(LcpRuby::MetadataError, /primary presenter 'project_public'.*not in the views list/)
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
                - presenter: project
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
                - presenter: project_public
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
              - presenter: project
                label: "Admin"
              - presenter: project_public
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
              - presenter: project
              - presenter: project_public
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
              - presenter: project
              - presenter: project_public
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
              - presenter: project
              - presenter: project_public
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
                - presenter: project
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
                - presenter: project
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
              - presenter: project
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
              - presenter: project
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
              - presenter: categories
        YAML
      )

      result = v.validate
      breadcrumb_errors = result.errors.select { |e| e.include?("breadcrumb") }
      expect(breadcrumb_errors).to be_empty
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
