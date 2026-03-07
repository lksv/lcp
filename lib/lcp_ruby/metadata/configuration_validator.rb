module LcpRuby
  module Metadata
    # Comprehensive configuration validator that checks both structural
    # integrity and business logic consistency across all YAML metadata.
    #
    # Unlike the per-definition validate! methods (which check individual
    # file syntax), this validator cross-references models, presenters,
    # and permissions to catch issues like broken associations, invalid
    # field references, duplicate slugs, etc.
    class ConfigurationValidator
      ValidationResult = Struct.new(:errors, :warnings, keyword_init: true) do
        def valid?
          errors.empty?
        end

        def to_s
          lines = []
          if errors.any?
            lines << "Errors (#{errors.size}):"
            errors.each { |e| lines << "  [ERROR] #{e}" }
          end
          if warnings.any?
            lines << "Warnings (#{warnings.size}):"
            warnings.each { |w| lines << "  [WARN]  #{w}" }
          end
          lines << "Configuration is valid." if valid? && warnings.empty?
          lines << "Configuration is valid (with warnings)." if valid? && warnings.any?
          lines.join("\n")
        end
      end

      ConditionValidationContext = Struct.new(:name, :model)
      VALID_CRUD_ACTIONS = %w[index show create update destroy restore permanently_destroy].freeze
      VALID_CONDITION_OPERATORS = %w[eq not_eq neq in not_in gt gte lt lte present blank matches not_matches starts_with ends_with contains not_contains any_of empty not_empty].freeze
      BUILT_IN_ACTION_NAMES = %w[show edit destroy create update restore permanently_destroy].freeze
      VALID_SORT_DIRECTIONS = %w[asc desc].freeze
      NUMERIC_OPERATORS = %w[gt gte lt lte].freeze
      REGEX_OPERATORS   = %w[matches not_matches].freeze
      STRING_OPERATORS  = %w[starts_with ends_with contains].freeze
      NUMERIC_TYPES     = %w[integer float decimal date datetime].freeze
      TEXT_TYPES         = %w[string text].freeze

      attr_reader :loader

      def initialize(loader)
        @loader = loader
        @errors = []
        @warnings = []
      end

      def validate
        @errors = []
        @warnings = []

        # Phase 1: Structural validation via JSON Schema
        validate_schemas

        # Phase 2: Cross-reference validation (semantic)
        validate_models
        validate_associations
        validate_presenters
        validate_permissions
        validate_uniqueness
        validate_view_groups
        validate_menu
        validate_custom_fields
        validate_role_model
        validate_permission_source_model
        validate_group_models

        ValidationResult.new(errors: @errors.dup, warnings: @warnings.dup)
      end

      private

      def validate_schemas
        schema_validator = SchemaValidator.new

        loader.model_definitions.each_value do |model|
          schema_validator.validate_model(model).each { |msg| @warnings << msg }
        end

        loader.presenter_definitions.each_value do |presenter|
          schema_validator.validate_presenter(presenter).each { |msg| @warnings << msg }
        end

        loader.permission_definitions.each_value do |permission|
          schema_validator.validate_permission(permission).each { |msg| @warnings << msg }
        end

        loader.view_group_definitions.each_value do |view_group|
          schema_validator.validate_view_group(view_group).each { |msg| @warnings << msg }
        end

        if loader.menu_definition
          schema_validator.validate_menu(loader.menu_definition).each { |msg| @warnings << msg }
        end
      end

      def model_names
        @model_names ||= loader.model_definitions.keys
      end

      def model_field_names(model_name)
        definition = loader.model_definitions[model_name]
        return [] unless definition

        definition.fields.map(&:name)
      end

      # Extended field list including userstamp columns, FKs, aggregates, timestamps
      # Used for condition validation where any DB column is valid
      def model_all_field_names(model_name)
        definition = loader.model_definitions[model_name]
        return [] unless definition

        fields = definition.fields.map(&:name)
        fk = definition.associations
          .select { |a| a.type == "belongs_to" && a.foreign_key }
          .flat_map { |a| cols = [ a.foreign_key.to_s ]; cols << "#{a.name}_type" if a.polymorphic; cols }
        userstamp = definition.userstamp_column_names
        aggregate = definition.aggregate_names
        fields + fk + userstamp + aggregate + %w[created_at updated_at id]
      end

      def model_field_definition(model_name, field_name)
        definition = loader.model_definitions[model_name]
        return nil unless definition

        definition.field(field_name.to_s)
      end

      def model_scope_names(model_name)
        definition = loader.model_definitions[model_name]
        return [] unless definition

        definition.scopes.map { |s| s.is_a?(Hash) ? (s["name"] || s[:name]).to_s : s.to_s }
      end

      def model_association_names(model_name)
        definition = loader.model_definitions[model_name]
        return [] unless definition

        names = definition.associations.map(&:name)

        # Include tree-generated associations (parent/children) that exist at runtime
        if definition.tree?
          names << definition.tree_parent_name unless names.include?(definition.tree_parent_name)
          names << definition.tree_children_name unless names.include?(definition.tree_children_name)
        end

        names
      end

      # --- Model validations ---

      def validate_models
        loader.model_definitions.each_value do |model|
          if model.virtual?
            validate_virtual_model(model)
          elsif model.api_model?
            validate_api_model(model)
          else
            validate_model_fields(model)
            validate_model_scopes(model)
            validate_model_events(model)
            validate_display_templates(model)
            validate_positioning(model)
            validate_soft_delete(model)
            validate_auditing(model)
            validate_userstamps(model)
            validate_tree(model)
            validate_label_method(model)
            validate_model_aggregates(model)
          end
        end
      end

      def validate_virtual_model(model)
        # Virtual models only serve as metadata definitions for json_field target_model.
        # Warn about features that don't apply to virtual models.
        validate_model_fields(model)

        if model.associations.any?
          @warnings << "Model '#{model.name}': virtual model (table_name: _virtual) " \
                       "has associations which will be ignored"
        end

        if model.scopes.any?
          @warnings << "Model '#{model.name}': virtual model (table_name: _virtual) " \
                       "has scopes which will be ignored"
        end

        if model.positioned?
          @warnings << "Model '#{model.name}': virtual model (table_name: _virtual) " \
                       "has positioning which will be ignored"
        end

        features = %w[soft_delete auditing userstamps tree]
        enabled = features.select { |f| model.send(:"#{f}?") }
        if enabled.any?
          @warnings << "Model '#{model.name}': model features (#{enabled.join(', ')}) " \
                       "have no effect on virtual models (table_name: _virtual)"
        end
      end

      def validate_api_model(model)
        validate_model_fields(model)

        ds = model.data_source_config

        # Validate data source type
        unless %w[rest_json host].include?(ds["type"])
          @errors << "Model '#{model.name}': data_source.type must be 'rest_json' or 'host', " \
                     "got '#{ds['type']}'"
        end

        # Type-specific validation
        if ds["type"] == "rest_json" && ds["base_url"].blank?
          @errors << "Model '#{model.name}': data_source.base_url is required for rest_json type"
        end

        if ds["type"] == "host" && ds["provider"].blank?
          @errors << "Model '#{model.name}': data_source.provider is required for host type"
        end

        # Validate auth type if present
        if ds["auth"].is_a?(Hash)
          valid_auth_types = %w[bearer basic header]
          unless valid_auth_types.include?(ds.dig("auth", "type"))
            @errors << "Model '#{model.name}': data_source.auth.type must be one of: " \
                       "#{valid_auth_types.join(', ')}"
          end
        end

        # Validate pagination style if present
        if ds["pagination"].is_a?(Hash)
          valid_styles = %w[offset_limit page_number cursor]
          style = ds.dig("pagination", "style")
          if style && !valid_styles.include?(style)
            @errors << "Model '#{model.name}': data_source.pagination.style must be one of: " \
                       "#{valid_styles.join(', ')}"
          end
        end

        # Incompatible features
        incompatible_features = %w[soft_delete auditing userstamps tree positioning custom_fields]
        incompatible_features.each do |feature|
          check_method = feature == "positioning" ? :positioned? : :"#{feature}?"
          check_method = :custom_fields_enabled? if feature == "custom_fields"
          if model.send(check_method)
            @errors << "Model '#{model.name}': '#{feature}' is not compatible with API-backed models"
          end
        end

        # Warn about AR-only scopes
        ar_scopes = model.scopes.select { |s| s["where"] || s["where_not"] }
        if ar_scopes.any?
          @warnings << "Model '#{model.name}': scopes with 'where'/'where_not' require ActiveRecord " \
                       "and will not work with API-backed models"
        end

        # Warn about SQL aggregates
        sql_aggregates = model.aggregates.select { |_, a| a.function.present? && a.service.blank? }
        if sql_aggregates.any?
          @warnings << "Model '#{model.name}': aggregates with SQL functions will not work " \
                       "with API-backed models (only service-based aggregates are supported)"
        end
      end

      def validate_model_fields(model)
        model.fields.each do |field|
          validate_enum_field(model, field) if field.enum?
          validate_virtual_field(model, field) if field.virtual?
          validate_array_field(model, field) if field.array?
        end
      end

      def validate_virtual_field(model, field)
        if field.service_accessor?
          service_key = field.source["service"]
          unless Services::Registry.registered?("accessors", service_key)
            @errors << "Model '#{model.name}', field '#{field.name}': " \
                       "accessor service '#{service_key}' not found"
          end

          options = field.source["options"]
          if options.is_a?(Hash) && options["column"]
            col = options["column"]
            ref_field = model.field(col)
            unless ref_field
              @errors << "Model '#{model.name}', field '#{field.name}': " \
                         "source references column '#{col}' which is not a defined field"
            end
            if ref_field&.virtual?
              @errors << "Model '#{model.name}', field '#{field.name}': " \
                         "source references column '#{col}' which is itself a virtual field"
            end
          end
        end

        if field.transforms.any?
          @warnings << "Model '#{model.name}', field '#{field.name}': " \
                       "transforms are ignored on virtual fields"
        end
      end

      def validate_array_field(model, field)
        unless Metadata::FieldDefinition::VALID_ARRAY_ITEM_TYPES.include?(field.item_type)
          @errors << "Model '#{model.name}', field '#{field.name}': " \
                     "array field requires item_type (#{Metadata::FieldDefinition::VALID_ARRAY_ITEM_TYPES.join(', ')}), " \
                     "got '#{field.item_type}'"
        end

        if field.default && !field.default.is_a?(Array)
          @errors << "Model '#{model.name}', field '#{field.name}': " \
                     "array field default must be an array, got #{field.default.class}"
        end
      end

      def validate_enum_field(model, field)
        if field.enum_values.empty?
          @errors << "Model '#{model.name}', field '#{field.name}': enum type requires enum_values"
        end

        if field.default && field.enum_values.any?
          valid_values = field.enum_value_names
          unless valid_values.include?(field.default.to_s)
            @errors << "Model '#{model.name}', field '#{field.name}': " \
                       "default value '#{field.default}' is not in enum_values #{valid_values}"
          end
        end
      end

      def validate_model_scopes(model)
        model.scopes.each do |scope|
          scope = scope.transform_keys(&:to_s) if scope.is_a?(Hash)
          next unless scope.is_a?(Hash)

          scope_name = scope["name"]
          next unless scope_name

          if scope["type"] == "parameterized"
            validate_parameterized_scope(model, scope_name, scope)
          else
            validate_scope_fields(model, scope_name, scope["where"])
            validate_scope_fields(model, scope_name, scope["where_not"])
            validate_scope_order_fields(model, scope_name, scope["order"])
          end
        end
      end

      VALID_PARAM_TYPES = %w[integer float decimal string enum date datetime boolean model_select].freeze

      def validate_parameterized_scope(model, scope_name, scope_config)
        parameters = scope_config["parameters"]

        unless parameters.is_a?(Array) && parameters.any?
          @errors << "Model '#{model.name}', parameterized scope '#{scope_name}': " \
                     "must have at least one parameter"
          return
        end

        param_names = []
        parameters.each do |param|
          param = param.transform_keys(&:to_s) if param.is_a?(Hash)
          next unless param.is_a?(Hash)

          name = param["name"]
          unless name.present?
            @errors << "Model '#{model.name}', parameterized scope '#{scope_name}': " \
                       "parameter is missing required 'name'"
            next
          end

          if param_names.include?(name)
            @errors << "Model '#{model.name}', parameterized scope '#{scope_name}': " \
                       "duplicate parameter name '#{name}'"
          end
          param_names << name

          type = param["type"]&.to_s
          unless type.present? && VALID_PARAM_TYPES.include?(type)
            @errors << "Model '#{model.name}', parameterized scope '#{scope_name}', " \
                       "parameter '#{name}': invalid type '#{type}'. " \
                       "Valid: #{VALID_PARAM_TYPES.join(', ')}"
            next
          end

          # Enum requires values
          if type == "enum" && !(param["values"].is_a?(Array) && param["values"].any?)
            @errors << "Model '#{model.name}', parameterized scope '#{scope_name}', " \
                       "parameter '#{name}': enum type requires 'values' array"
          end

          # model_select requires model reference
          if type == "model_select" && !param["model"].present?
            @errors << "Model '#{model.name}', parameterized scope '#{scope_name}', " \
                       "parameter '#{name}': model_select type requires 'model' reference"
          end

          # min/max validation for numeric types
          if %w[integer float].include?(type) && param["min"] && param["max"]
            if param["min"].to_f > param["max"].to_f
              @errors << "Model '#{model.name}', parameterized scope '#{scope_name}', " \
                         "parameter '#{name}': min (#{param['min']}) must be <= max (#{param['max']})"
            end
          end
        end
      end

      def validate_scope_fields(model, scope_name, where_clause)
        return unless where_clause.is_a?(Hash)

        field_names = model.fields.map(&:name)
        where_clause.each_key do |field_name|
          unless field_names.include?(field_name.to_s)
            @warnings << "Model '#{model.name}', scope '#{scope_name}': " \
                         "references unknown field '#{field_name}'"
          end
          ref_field = model.field(field_name.to_s)
          if ref_field&.virtual?
            @warnings << "Model '#{model.name}', scope '#{scope_name}': " \
                         "references virtual field '#{field_name}' which has no DB column"
          end
        end
      end

      def validate_scope_order_fields(model, scope_name, order_clause)
        return unless order_clause.is_a?(Hash)

        field_names = model.fields.map(&:name) + %w[created_at updated_at id]
        order_clause.each_key do |field_name|
          unless field_names.include?(field_name.to_s)
            @warnings << "Model '#{model.name}', scope '#{scope_name}': " \
                         "orders by unknown field '#{field_name}'"
          end
        end
      end

      def validate_model_aggregates(model)
        # Name collision with fields is already checked by ModelDefinition#validate! at parse time.
        model.aggregates.each do |agg_name, agg_def|
          if agg_def.declarative?
            validate_declarative_aggregate(model, agg_name, agg_def)
          elsif agg_def.sql_type?
            validate_sql_aggregate(model, agg_name, agg_def)
          elsif agg_def.service_type?
            validate_service_aggregate(model, agg_name, agg_def)
          end
        end
      end

      def validate_declarative_aggregate(model, agg_name, agg_def)
        # Verify association exists and is has_many
        assoc = model.associations.find { |a| a.name == agg_def.association }
        unless assoc
          @errors << "Model '#{model.name}', aggregate '#{agg_name}': " \
                     "references unknown association '#{agg_def.association}'"
          return
        end
        unless assoc.type == "has_many"
          @errors << "Model '#{model.name}', aggregate '#{agg_name}': " \
                     "association '#{agg_def.association}' must be has_many, got '#{assoc.type}'"
          return
        end

        # Verify source_field exists on target model
        if agg_def.source_field.present? && assoc.target_model
          target_def = loader.model_definitions[assoc.target_model]
          if target_def && !target_def.field(agg_def.source_field)
            @errors << "Model '#{model.name}', aggregate '#{agg_name}': " \
                       "source_field '#{agg_def.source_field}' not found on model '#{assoc.target_model}'"
          end
        end

        # Verify where clause fields exist on target model
        if agg_def.where.present? && assoc.target_model
          target_def = loader.model_definitions[assoc.target_model]
          if target_def
            target_fields = target_def.fields.map(&:name) + %w[id created_at updated_at]
            agg_def.where.each_key do |where_field|
              unless target_fields.include?(where_field.to_s)
                @warnings << "Model '#{model.name}', aggregate '#{agg_name}': " \
                             "where clause references field '#{where_field}' not found on model '#{assoc.target_model}'"
              end
            end
          end
        end
      end

      # SQL and service aggregate type checks are handled by AggregateDefinition#validate!
      # at parse time (raises MetadataError if type is missing).
      def validate_sql_aggregate(_model, _agg_name, _agg_def); end
      def validate_service_aggregate(_model, _agg_name, _agg_def); end

      def validate_model_events(model)
        model.events.each do |event|
          next unless event.field_change?

          field_names = model.fields.map(&:name)
          unless field_names.include?(event.field.to_s)
            @errors << "Model '#{model.name}', event '#{event.name}': " \
                       "field_change references unknown field '#{event.field}'"
          end
        end
      end

      def validate_display_templates(model)
        return if model.display_templates.empty?

        valid_fields = model.fields.map(&:name) + %w[created_at updated_at id]
        model.display_templates.each_value do |tmpl|
          next unless tmpl.structured?

          tmpl.referenced_fields.each do |ref|
            # Skip dot-path references (e.g., "category.name") — validated at runtime
            next if ref.include?(".")

            unless valid_fields.include?(ref)
              @warnings << "Model '#{model.name}', display template '#{tmpl.name}': " \
                           "references unknown field '#{ref}'"
            end
          end
        end
      end

      def validate_positioning(model)
        return unless model.positioned?

        config = model.positioning_config
        field_name = config["field"] || "position"
        field_def = model.field(field_name)

        unless field_def
          @errors << "Model '#{model.name}': positioning field '#{field_name}' is not defined"
          return
        end

        unless field_def.type == "integer"
          @errors << "Model '#{model.name}': positioning field '#{field_name}' must be type 'integer', got '#{field_def.type}'"
        end

        if field_def.virtual?
          @errors << "Model '#{model.name}': positioning field '#{field_name}' cannot be a virtual field"
        end

        Array(config["scope"]).each do |scope_col|
          scope_field = model.field(scope_col)
          scope_fk = model.associations.any? { |a| a.foreign_key == scope_col }
          unless scope_field || scope_fk
            @errors << "Model '#{model.name}': positioning scope '#{scope_col}' is not a defined field or FK"
          end
        end
      end

      def validate_boolean_or_hash_option(model, option_name, allowed_keys: [])
        value = model.options[option_name]
        return nil unless value

        unless value == true || value.is_a?(Hash)
          @errors << "Model '#{model.name}': #{option_name} must be true or a Hash, got #{value.class}"
          return nil
        end

        return {} if value == true

        unknown = value.keys - allowed_keys
        if unknown.any?
          @errors << "Model '#{model.name}': #{option_name} has unknown keys: #{unknown.join(', ')}. " \
                     "Allowed keys: #{allowed_keys.join(', ')}"
        end

        value
      end

      def validate_soft_delete(model)
        opts = validate_boolean_or_hash_option(model, "soft_delete", allowed_keys: %w[column])
        return unless opts.is_a?(Hash) && opts.any?

        if opts.key?("column") && !opts["column"].is_a?(String)
          @errors << "Model '#{model.name}': soft_delete.column must be a string, got #{opts["column"].class}"
        end
      end

      def validate_auditing(model)
        opts = validate_boolean_or_hash_option(
          model, "auditing",
          allowed_keys: %w[only ignore track_associations track_attachments expand_custom_fields expand_json_fields]
        )
        return unless model.auditing?
        return unless opts.is_a?(Hash) && opts.any?

        if opts.key?("only") && opts.key?("ignore")
          @errors << "Model '#{model.name}': auditing.only and auditing.ignore are mutually exclusive"
        end

        # Validate only/ignore field references
        field_names = model.fields.map(&:name)
        %w[only ignore].each do |key|
          next unless opts.key?(key)

          unknown = Array(opts[key]).map(&:to_s) - field_names
          if unknown.any?
            @warnings << "Model '#{model.name}': auditing.#{key} references unknown fields: #{unknown.join(', ')}"
          end
        end

        # Validate expand_json_fields references JSON-type fields
        if opts.key?("expand_json_fields")
          Array(opts["expand_json_fields"]).each do |field_name|
            field = model.field(field_name.to_s)
            if field.nil?
              @warnings << "Model '#{model.name}': auditing.expand_json_fields references unknown field '#{field_name}'"
            elsif !%w[json jsonb].include?(field.type)
              @warnings << "Model '#{model.name}': auditing.expand_json_fields field '#{field_name}' is type '#{field.type}', expected 'json'"
            end
          end
        end
      end

      def validate_userstamps(model)
        opts = validate_boolean_or_hash_option(model, "userstamps", allowed_keys: %w[created_by updated_by store_name])
        return unless opts

        [ model.userstamps_creator_field, model.userstamps_updater_field ].each do |col|
          if model.field(col)
            @errors << "Model '#{model.name}': userstamps column '#{col}' conflicts with an explicitly defined field"
          end
        end

        if model.userstamps_store_name?
          [ model.userstamps_creator_name_field, model.userstamps_updater_name_field ].each do |col|
            if model.field(col)
              @errors << "Model '#{model.name}': userstamps name column '#{col}' conflicts with an explicitly defined field"
            end
          end
        end

        unless model.timestamps?
          @warnings << "Model '#{model.name}': userstamps enabled without timestamps — consider enabling timestamps too"
        end
      end

      def validate_tree(model)
        opts = validate_boolean_or_hash_option(
          model, "tree",
          allowed_keys: %w[parent_field children_name parent_name dependent max_depth ordered position_field]
        )
        return unless opts

        parent_field = model.tree_parent_field
        children_name = model.tree_children_name
        parent_name = model.tree_parent_name

        # parent_field must exist in fields and be integer type
        field_def = model.field(parent_field)
        if field_def.nil?
          @errors << "Model '#{model.name}': tree parent_field '#{parent_field}' must be declared in fields"
        elsif field_def.type != "integer"
          @errors << "Model '#{model.name}': tree parent_field '#{parent_field}' must be type integer, got '#{field_def.type}'"
        else
          # Must be nullable (optional: true is default for belongs_to in tree)
          col_opts = field_def.respond_to?(:column_options) ? field_def.column_options : {}
          if col_opts.is_a?(Hash) && col_opts["null"] == false
            @errors << "Model '#{model.name}': tree parent_field '#{parent_field}' must be nullable (null: true or omit null option) — root nodes have NULL parent"
          end
        end

        # dependent must be a valid enum
        valid_dependents = %w[destroy nullify restrict_with_exception restrict_with_error discard]
        dep = model.tree_dependent
        unless valid_dependents.include?(dep)
          @errors << "Model '#{model.name}': tree dependent '#{dep}' is invalid. " \
                     "Allowed values: #{valid_dependents.join(', ')}"
        end

        # discard requires soft_delete
        if dep == "discard" && !model.soft_delete?
          @errors << "Model '#{model.name}': tree dependent: discard requires soft_delete to be enabled"
        end

        # max_depth must be positive integer
        max_depth = model.tree_max_depth
        unless max_depth.is_a?(Integer) && max_depth > 0
          @errors << "Model '#{model.name}': tree max_depth must be a positive integer, got '#{max_depth}'"
        end

        # ordered: true requires position field to exist and be integer
        if model.tree_ordered?
          pos_field = model.tree_position_field
          pos_field_def = model.field(pos_field)
          if pos_field_def.nil?
            @errors << "Model '#{model.name}': tree ordered: true requires position_field '#{pos_field}' " \
                       "to be declared in fields"
          elsif pos_field_def.type != "integer"
            @errors << "Model '#{model.name}': tree position_field '#{pos_field}' must be type integer, " \
                       "got '#{pos_field_def.type}'"
          end

          # Warn if explicit positioning is also configured
          if model.positioned?
            @warnings << "Model '#{model.name}': tree ordered: true auto-configures positioning — " \
                         "the explicit positioning config may be overridden"
          end
        end

        # Conflict detection: manual associations with same name
        model.associations.each do |assoc|
          if assoc.name == parent_name && assoc.type == "belongs_to"
            @warnings << "Model '#{model.name}': manual belongs_to :#{parent_name} association " \
                         "conflicts with tree-generated parent association — tree will override it"
          end
          if assoc.name == children_name && assoc.type == "has_many"
            @warnings << "Model '#{model.name}': manual has_many :#{children_name} association " \
                         "conflicts with tree-generated children association — tree will override it"
          end
        end
      end

      def validate_label_method(model)
        label_attr = model.options["label_method"]

        if label_attr.nil?
          @warnings << "Model '#{model.name}': no label_method defined — records will display " \
                       "as '#<ClassName:0x...>' in headlines and breadcrumbs. " \
                       "Add label_method to options (e.g., label_method: name)"
          return
        end

        field_names = model.fields.map(&:name)
        assoc_names = model.associations.map(&:name)
        unless field_names.include?(label_attr.to_s) || assoc_names.include?(label_attr.to_s)
          @warnings << "Model '#{model.name}': label_method '#{label_attr}' is not a defined " \
                       "field or association — records may display incorrectly"
        end
      end

      def validate_presenter_reorderable(presenter, model)
        return unless presenter.reorderable?

        unless model.positioned?
          @errors << "Presenter '#{presenter.name}': index.reorderable is true but model '#{model.name}' has no positioning config"
        end
      end

      def validate_presenter_tree_view(presenter, model)
        if presenter.index_layout == :tree && !model.tree?
          @errors << "Presenter '#{presenter.name}': layout 'tree' requires model '#{model.name}' to have tree enabled"
        end

        # Detect layout conflict: explicit layout: tiles/table + tree_view: true
        explicit_layout = presenter.index_config["layout"]
        if explicit_layout && explicit_layout != "tree" && presenter.index_config["tree_view"] == true
          @errors << "Presenter '#{presenter.name}': layout '#{explicit_layout}' conflicts with tree_view: true"
        end

        if presenter.reparentable? && !presenter.tree_view?
          @errors << "Presenter '#{presenter.name}': index.reparentable requires tree layout"
        end

        if presenter.reparentable? && !model.tree?
          @errors << "Presenter '#{presenter.name}': index.reparentable requires model '#{model.name}' to have tree enabled"
        end
      end

      def validate_presenter_deprecations(presenter)
        if presenter.index_config["tree_view"] == true
          @warnings << "Presenter '#{presenter.name}': index.tree_view is deprecated, use index.layout: tree instead"
        end

        if presenter.index_config["default_view"].present?
          @warnings << "Presenter '#{presenter.name}': index.default_view is deprecated, use view groups instead"
        end

        if presenter.index_config["views_available"].present?
          @warnings << "Presenter '#{presenter.name}': index.views_available is deprecated, use view groups instead"
        end
      end

      VALID_CARD_LINK_VALUES = %w[show edit].freeze
      VALID_ACTIONS_VALUES = %w[dropdown inline none].freeze

      def validate_presenter_tiles(presenter, model)
        return unless presenter.tiles?

        tile = presenter.tile_config
        unless tile["title_field"].present?
          @errors << "Presenter '#{presenter.name}': layout 'tiles' requires tile.title_field"
          return
        end

        valid_fields = build_all_valid_fields(presenter, model)

        # Validate tile field references
        Metadata::PresenterDefinition::TILE_NAMED_FIELD_KEYS.each do |key|
          field_name = tile[key]
          next unless field_name
          next if Presenter::FieldValueResolver.dot_path?(field_name) || Presenter::FieldValueResolver.template_field?(field_name)

          unless valid_fields.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', tile.#{key}: " \
                       "references unknown field '#{field_name}' on model '#{presenter.model}'"
          end
        end

        (tile["fields"] || []).each do |f|
          field_name = f["field"]
          unless field_name.present?
            @errors << "Presenter '#{presenter.name}', tile.fields: entry is missing 'field'"
            next
          end
          next if Presenter::FieldValueResolver.dot_path?(field_name) || Presenter::FieldValueResolver.template_field?(field_name)

          unless valid_fields.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', tile.fields: " \
                       "references unknown field '#{field_name}' on model '#{presenter.model}'"
          end
        end

        # Validate tile.columns
        columns = tile["columns"]
        if columns && (!columns.is_a?(Integer) || columns < 1)
          @errors << "Presenter '#{presenter.name}', tile.columns: must be a positive integer, got '#{columns}'"
        end

        # Validate tile.card_link
        card_link = tile["card_link"]
        if card_link && !VALID_CARD_LINK_VALUES.include?(card_link.to_s)
          @errors << "Presenter '#{presenter.name}', tile.card_link: " \
                     "invalid value '#{card_link}'. Valid: #{VALID_CARD_LINK_VALUES.join(', ')}"
        end

        # Validate tile.actions
        actions = tile["actions"]
        if actions && !VALID_ACTIONS_VALUES.include?(actions.to_s)
          @errors << "Presenter '#{presenter.name}', tile.actions: " \
                     "invalid value '#{actions}'. Valid: #{VALID_ACTIONS_VALUES.join(', ')}"
        end

        # Validate tile.description_max_lines
        max_lines = tile["description_max_lines"]
        if max_lines && (!max_lines.is_a?(Integer) || max_lines < 1)
          @errors << "Presenter '#{presenter.name}', tile.description_max_lines: must be a positive integer, got '#{max_lines}'"
        end

        if presenter.reorderable?
          @warnings << "Presenter '#{presenter.name}': reorderable with tiles layout may not provide a good user experience"
        end
      end

      VALID_CSS_CLASS_PATTERN = /\A[a-zA-Z0-9\s_-]+\z/

      def validate_presenter_item_classes(presenter, _model_def)
        rules = presenter.item_classes
        return if rules.empty?

        rules.each_with_index do |rule, i|
          css_class = rule["class"]
          if css_class.nil? || !css_class.is_a?(String) || css_class.strip.empty?
            @errors << "Presenter '#{presenter.name}', index item_classes[#{i}]: " \
                       "'class' must be a non-empty string"
          elsif !css_class.match?(VALID_CSS_CLASS_PATTERN)
            @errors << "Presenter '#{presenter.name}', index item_classes[#{i}]: " \
                       "'class' contains invalid characters (only letters, digits, hyphens, underscores, and spaces are allowed)"
          end

          condition = rule["when"]
          unless condition.is_a?(Hash)
            @errors << "Presenter '#{presenter.name}', index item_classes[#{i}]: " \
                       "'when' must be a condition hash"
            next
          end

          validate_condition(presenter, condition, "index item_classes[#{i}]")
        end
      end

      # Warns when associations referenced in index conditions are not covered by explicit includes.
      # DependencyCollector auto-includes these at runtime, so these are informational warnings.
      def validate_condition_eager_loading(presenter, model_def)
        # Gather index-context conditions: item_classes[].when, action visible_when/disable_when
        index_conditions = []

        presenter.item_classes.each_with_index do |rule, i|
          condition = rule["when"]
          index_conditions << [ condition, "item_classes[#{i}]" ] if condition.is_a?(Hash)
        end

        all_actions = presenter.single_actions + presenter.collection_actions + presenter.batch_actions
        all_actions.each do |action|
          %w[visible_when disable_when].each do |key|
            cond = action[key]
            index_conditions << [ cond, "action '#{action['name']}', #{key}" ] if cond.is_a?(Hash)
          end
        end

        return if index_conditions.empty?

        declared = declared_index_includes(presenter)

        index_conditions.each do |condition, label|
          refs = collect_condition_assoc_refs(condition, model_def)
          refs.each do |assoc_name|
            unless declared.include?(assoc_name)
              @warnings << "Presenter '#{presenter.name}' index: #{label} references " \
                           "'#{assoc_name}' but index.includes does not contain '#{assoc_name}'. " \
                           "Add 'includes: [#{assoc_name}]' to the index configuration to avoid N+1 queries."
            end
          end
        end
      end

      # Returns Set of top-level association names declared in index includes/eager_load.
      def declared_index_includes(presenter)
        config = presenter.index_config
        return Set.new unless config.is_a?(Hash)

        names = Set.new
        %w[includes eager_load].each do |key|
          entries = config[key]
          next unless entries.is_a?(Array)

          entries.each do |entry|
            case entry
            when String
              names << entry
            when Hash
              entry.each_key { |k| names << k.to_s }
            end
          end
        end
        names
      end

      # Recursively walks a condition tree and collects association references.
      # Returns a Set of top-level association names referenced by dot-paths,
      # collections, and value field_ref dot-paths.
      def collect_condition_assoc_refs(condition, model_def)
        refs = Set.new
        walk_condition_for_assoc_refs(condition, model_def, refs)
        refs
      end

      def walk_condition_for_assoc_refs(condition, model_def, refs)
        return unless condition.is_a?(Hash)

        normalized = condition.transform_keys(&:to_s)

        if normalized.key?("all") || normalized.key?("any")
          children = normalized["all"] || normalized["any"]
          Array(children).each { |child| walk_condition_for_assoc_refs(child, model_def, refs) }
        elsif normalized.key?("not")
          walk_condition_for_assoc_refs(normalized["not"], model_def, refs)
        elsif normalized.key?("collection")
          collection_name = normalized["collection"].to_s
          refs << collection_name
          # Note: inner condition refs are on the target model, would need nested includes.
          # For now we just flag the top-level collection.
        elsif normalized.key?("field")
          field = normalized["field"].to_s
          if field.include?(".")
            refs << field.split(".").first
          end

          # Check value references for dot-paths
          value = normalized["value"]
          if value.is_a?(Hash)
            ref = value.transform_keys(&:to_s)["field_ref"]
            if ref && ref.to_s.include?(".")
              refs << ref.to_s.split(".").first
            end
          end
        end
      end

      def validate_presenter_summary(presenter, model)
        return unless presenter.summary_enabled?

        fields = presenter.summary_config["fields"]
        return unless fields.is_a?(Array)

        valid_fields = build_all_valid_fields(presenter, model)

        fields.each do |f|
          field_name = f["field"]
          function = f["function"]

          unless field_name.present?
            @errors << "Presenter '#{presenter.name}', summary.fields: entry is missing 'field'"
            next
          end

          unless valid_fields.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', summary.fields: " \
                       "references unknown field '#{field_name}' on model '#{presenter.model}'"
          end

          unless function.present? && AggregateDefinition::VALID_FUNCTIONS.include?(function.to_s)
            @errors << "Presenter '#{presenter.name}', summary.fields: " \
                       "field '#{field_name}' has invalid function '#{function}'. " \
                       "Valid: #{AggregateDefinition::VALID_FUNCTIONS.join(', ')}"
          end
        end
      end

      def validate_presenter_sort_fields(presenter, model)
        sort_fields = presenter.sort_fields
        return unless sort_fields.any?

        valid_fields = build_all_valid_fields(presenter, model)

        sort_fields.each do |sf|
          field_name = sf["field"]
          unless field_name.present?
            @errors << "Presenter '#{presenter.name}', sort_fields: entry is missing 'field'"
            next
          end
          next if Presenter::FieldValueResolver.dot_path?(field_name)

          unless valid_fields.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', sort_fields: " \
                       "references unknown field '#{field_name}' on model '#{presenter.model}'"
          end
        end
      end

      def validate_presenter_per_page_options(presenter)
        options = presenter.per_page_options
        return unless options

        unless options.is_a?(Array) && options.all? { |n| n.is_a?(Integer) && n > 0 }
          @errors << "Presenter '#{presenter.name}': per_page_options must be an array of positive integers"
          return
        end

        if !options.include?(presenter.per_page)
          @warnings << "Presenter '#{presenter.name}': per_page (#{presenter.per_page}) is not in per_page_options #{options}"
        end
      end

      def build_all_valid_fields(presenter, model)
        valid = model.fields.map(&:name)
        fk = model.associations
          .select { |a| a.type == "belongs_to" && a.foreign_key }
          .flat_map { |a| cols = [ a.foreign_key.to_s ]; cols << "#{a.name}_type" if a.polymorphic; cols }
        collection_ids = model.associations
          .select(&:through?)
          .map { |a| "#{a.name.to_s.singularize}_ids" }
        userstamp = model.userstamp_column_names
        aggregate = model.aggregate_names
        valid + fk + collection_ids + userstamp + aggregate + %w[created_at updated_at id]
      end

      def validate_positioning_field_not_in_form(presenter, model)
        return unless model.positioned?

        pos_field = model.positioning_field
        sections = presenter.form_config["sections"] || []
        sections.each do |section|
          next unless section.is_a?(Hash)

          fields = section["fields"] || []
          if fields.any? { |f| f.is_a?(Hash) ? f["field"] == pos_field : f.to_s == pos_field }
            @warnings << "Presenter '#{presenter.name}': positioning field '#{pos_field}' appears in a form section. " \
                         "The position is managed automatically via drag-and-drop; editing it manually in a form may cause " \
                         "confusing behavior. Consider removing it from the form."
          end
        end
      end

      # --- Association validations ---

      def validate_associations
        loader.model_definitions.each_value do |model|
          model.associations.each do |assoc|
            validate_association(model, assoc)
          end
        end

        validate_association_reciprocity
      end

      def validate_association(model, assoc)
        if assoc.lcp_model?
          unless model_names.include?(assoc.target_model)
            @errors << "Model '#{model.name}', association '#{assoc.name}': " \
                       "target_model '#{assoc.target_model}' does not exist. " \
                       "Available models: #{model_names.join(', ')}"
          end
        end

        validate_association_foreign_key(model, assoc) if assoc.type == "belongs_to" && !assoc.polymorphic
        validate_through_reference(model, assoc) if assoc.through?
        validate_dependent_discard(model, assoc) if assoc.dependent == :discard
      end

      def validate_dependent_discard(model, assoc)
        if assoc.type == "belongs_to"
          @errors << "Model '#{model.name}', association '#{assoc.name}': " \
                     "dependent: :discard is not valid on belongs_to associations"
          return
        end

        if assoc.lcp_model?
          target = loader.model_definitions[assoc.target_model]
          if target && !target.soft_delete?
            @errors << "Model '#{model.name}', association '#{assoc.name}': " \
                       "dependent: :discard requires target model '#{assoc.target_model}' to have soft_delete enabled"
          end
        end

        unless model.soft_delete?
          @warnings << "Model '#{model.name}', association '#{assoc.name}': " \
                       "dependent: :discard on a model without soft_delete — " \
                       "cascade discard will only trigger if the parent is discarded"
        end
      end

      def validate_through_reference(model, assoc)
        assoc_names = model.associations.map(&:name)
        unless assoc_names.include?(assoc.through)
          @errors << "Model '#{model.name}', association '#{assoc.name}': " \
                     "through '#{assoc.through}' does not match any association on this model. " \
                     "Available associations: #{assoc_names.join(', ')}"
        end
      end

      def validate_association_foreign_key(model, assoc)
        return unless assoc.foreign_key

        fk = assoc.foreign_key.to_s
        field_names = model.fields.map(&:name)
        # FK fields are often auto-managed (not in YAML fields list), so this is just a warning
        if field_names.include?(fk)
          @warnings << "Model '#{model.name}': foreign key '#{fk}' is listed as both " \
                       "a field and an association FK. The FK column is auto-managed by the association."
        end
      end

      def validate_association_reciprocity
        loader.model_definitions.each_value do |model|
          model.associations.each do |assoc|
            next unless assoc.lcp_model?
            # Skip reciprocity for polymorphic, as, and through associations
            next if assoc.polymorphic || assoc.as.present? || assoc.through?

            target = loader.model_definitions[assoc.target_model]
            next unless target

            case assoc.type
            when "belongs_to"
              has_inverse = target.associations.any? do |ta|
                ta.lcp_model? &&
                  ta.target_model == model.name &&
                  %w[has_many has_one].include?(ta.type)
              end
              unless has_inverse
                @warnings << "Model '#{model.name}', association '#{assoc.name}' (belongs_to): " \
                             "no corresponding has_many/has_one found on model '#{assoc.target_model}'"
              end
            when "has_many", "has_one"
              has_inverse = target.associations.any? do |ta|
                ta.lcp_model? &&
                  ta.target_model == model.name &&
                  ta.type == "belongs_to"
              end
              unless has_inverse
                @warnings << "Model '#{model.name}', association '#{assoc.name}' (#{assoc.type}): " \
                             "no corresponding belongs_to found on model '#{assoc.target_model}'"
              end
            end
          end
        end
      end

      # --- Presenter validations ---

      def validate_presenters
        loader.presenter_definitions.each_value do |presenter|
          validate_presenter_model(presenter)
          validate_presenter_fields(presenter)
          validate_presenter_scopes(presenter)
          validate_presenter_advanced_filter(presenter)
          validate_presenter_actions(presenter)
          validate_presenter_deprecations(presenter)

          model_def = loader.model_definitions[presenter.model]
          if model_def
            validate_presenter_reorderable(presenter, model_def)
            validate_positioning_field_not_in_form(presenter, model_def)
            validate_presenter_tree_view(presenter, model_def)
            validate_presenter_tiles(presenter, model_def)
            validate_presenter_item_classes(presenter, model_def)
            validate_condition_eager_loading(presenter, model_def)
            validate_presenter_summary(presenter, model_def)
            validate_presenter_sort_fields(presenter, model_def)
            validate_presenter_per_page_options(presenter)
          end
        end
      end

      def validate_presenter_model(presenter)
        unless model_names.include?(presenter.model)
          @errors << "Presenter '#{presenter.name}': references unknown model '#{presenter.model}'"
        end
      end

      def validate_presenter_fields(presenter)
        model_def = loader.model_definitions[presenter.model]
        return unless model_def

        valid_fields = model_def.fields.map(&:name)
        fk_fields = model_def.associations
          .select { |a| a.type == "belongs_to" && a.foreign_key }
          .flat_map { |a|
            cols = [ a.foreign_key.to_s ]
            cols << "#{a.name}_type" if a.polymorphic
            cols
          }
        # has_many :through associations expose *_ids accessor (e.g., tag_ids for has_many :tags)
        collection_id_fields = model_def.associations
          .select { |a| a.through? }
          .map { |a| "#{a.name.to_s.singularize}_ids" }
        userstamp_fields = model_def.userstamp_column_names
        aggregate_fields = model_def.aggregate_names
        all_valid = valid_fields + fk_fields + collection_id_fields + userstamp_fields + aggregate_fields + %w[created_at updated_at id]

        # Check table columns
        presenter.table_columns.each do |col|
          col = col.transform_keys(&:to_s) if col.is_a?(Hash)
          field_name = col.is_a?(Hash) ? col["field"] : col.to_s
          next unless field_name

          # Skip validation for dot-path and template fields (validated at runtime)
          next if Presenter::FieldValueResolver.dot_path?(field_name) || Presenter::FieldValueResolver.template_field?(field_name)

          unless all_valid.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', table_columns: " \
                       "references unknown field '#{field_name}' on model '#{presenter.model}'"
          end
        end

        # Check form fields
        validate_presenter_section_fields(presenter, presenter.form_config, "form", all_valid)
        # Check show fields
        validate_presenter_section_fields(presenter, presenter.show_config, "show", all_valid)

        validate_presenter_default_sort(presenter, all_valid)
        validate_presenter_includes(presenter)
      end

      def validate_presenter_section_fields(presenter, config, config_name, valid_fields)
        sections = config["sections"] || config["layout"] || []
        sections.each do |section|
          section = section.transform_keys(&:to_s) if section.is_a?(Hash)
          next unless section.is_a?(Hash)

          section_type = section["type"]

          # Validate section-level conditions (for ALL section types including association_list)
          %w[visible_when disable_when].each do |cond_key|
            condition = section[cond_key]
            next unless condition.is_a?(Hash)

            section_label = section["title"] || section["section"] || "(unnamed)"
            validate_condition(presenter, condition, "#{config_name} section '#{section_label}', #{cond_key}")
          end

          # Validate association reference for nested_fields, association_list, and json_items_list sections
          if %w[nested_fields association_list json_items_list].include?(section_type)
            if section["json_field"]
              validate_section_json_field(presenter, section, config_name)
              validate_json_field_conditions(presenter, section, config_name) if section_type == "nested_fields"
            else
              validate_section_association(presenter, section, config_name)
              validate_nested_field_conditions(presenter, section, config_name) if section_type == "nested_fields"
            end
            next # Fields belong to the associated/target model — skip field-level validation
          end

          fields = section["fields"] || []

          fields.each do |f|
            f = f.transform_keys(&:to_s) if f.is_a?(Hash)
            field_name = f.is_a?(Hash) ? f["field"] : f.to_s
            next unless field_name

            # Skip validation for dot-path and template fields (validated at runtime)
            unless Presenter::FieldValueResolver.dot_path?(field_name) || Presenter::FieldValueResolver.template_field?(field_name) || valid_fields.include?(field_name.to_s)
              @errors << "Presenter '#{presenter.name}', #{config_name}: " \
                         "references unknown field '#{field_name}' on model '#{presenter.model}'"
            end

            # Validate field-level conditions
            next unless f.is_a?(Hash)

            %w[visible_when disable_when].each do |cond_key|
              condition = f[cond_key]
              next unless condition.is_a?(Hash)

              validate_condition(presenter, condition, "#{config_name} field '#{field_name}', #{cond_key}")
            end
          end
        end
      end

      # Validate json_field sections: ensure the field exists and is type json
      def validate_section_json_field(presenter, section, config_name)
        json_field_name = section["json_field"]
        section_label = section["title"] || "(unnamed)"

        model_def = loader.model_definitions[presenter.model]
        return unless model_def

        field_def = model_def.field(json_field_name)
        unless field_def
          @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                     "json_field '#{json_field_name}' does not exist on model '#{presenter.model}'"
          return
        end

        unless field_def.type == "json"
          @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                     "json_field '#{json_field_name}' must be type 'json', got '#{field_def.type}'"
        end

        # Validate mutual exclusivity with association
        if section["association"]
          @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                     "nested_fields cannot have both 'association' and 'json_field'"
        end

        # Validate mutual exclusivity of fields and sub_sections
        if section["fields"] && section["sub_sections"]
          @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                     "nested_fields cannot have both 'fields' and 'sub_sections'"
        end

        # If target_model is specified, validate field references against it
        target_model_name = section["target_model"]
        if target_model_name
          target_def = loader.model_definitions[target_model_name]
          unless target_def
            @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                       "target_model '#{target_model_name}' does not exist"
            return
          end

          target_field_names = target_def.fields.map(&:name)

          # Validate fields (flat mode)
          all_fields = section["fields"] || []

          # Validate sub_sections fields
          (section["sub_sections"] || []).each do |ss|
            all_fields += (ss["fields"] || [])
          end

          all_fields.each do |f|
            f = f.transform_keys(&:to_s) if f.is_a?(Hash)
            next unless f.is_a?(Hash) && f["field"]

            unless target_field_names.include?(f["field"].to_s)
              @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                         "field '#{f['field']}' does not exist on target_model '#{target_model_name}'"
            end
          end
        end
      end

      def validate_section_association(presenter, section, config_name)
        assoc_name = section["association"]
        return unless assoc_name

        assoc_names = model_association_names(presenter.model)
        section_label = section["title"] || section["section"] || "(unnamed)"

        unless assoc_names.include?(assoc_name.to_s)
          @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                     "#{section['type']} references unknown association '#{assoc_name}' on model '#{presenter.model}'"
          return
        end

        # Validate that field references exist on the target model (or match an FK)
        validate_nested_field_references(presenter, section, config_name)
      end

      # Validate that fields referenced in a nested_fields (association) section
      # exist on the target model — either as declared fields or as association FK columns.
      def validate_nested_field_references(presenter, section, config_name)
        assoc_name = section["association"]
        return unless assoc_name

        model_def = loader.model_definitions[presenter.model]
        return unless model_def

        assoc = model_def.associations.find { |a| a.name == assoc_name }
        return unless assoc&.target_model

        target_def = loader.model_definitions[assoc.target_model]
        return unless target_def

        target_field_names = target_def.fields.map(&:name)
        target_fk_names = target_def.associations.map(&:foreign_key).compact.map(&:to_s)
        valid_names = target_field_names + target_fk_names
        section_label = section["title"] || "(unnamed)"

        all_fields = section["fields"] || []
        (section["sub_sections"] || []).each do |ss|
          all_fields += (ss["fields"] || [])
        end

        all_fields.each do |f|
          f = f.transform_keys(&:to_s) if f.is_a?(Hash)
          next unless f.is_a?(Hash) && f["field"]

          unless valid_names.include?(f["field"].to_s)
            @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                       "field '#{f['field']}' does not exist on target model '#{assoc.target_model}'"
          end
        end
      end

      # Validate field-level conditions in nested_fields sections against the target model
      def validate_nested_field_conditions(presenter, section, config_name)
        assoc_name = section["association"]
        return unless assoc_name

        # Resolve the target model through the association
        model_def = loader.model_definitions[presenter.model]
        return unless model_def

        assoc = model_def.associations.find { |a| a.name == assoc_name }
        return unless assoc&.target_model

        target_def = loader.model_definitions[assoc.target_model]
        return unless target_def

        target_field_names = target_def.fields.map(&:name)
        section_label = section["title"] || "(unnamed)"

        (section["fields"] || []).each do |f|
          f = f.transform_keys(&:to_s) if f.is_a?(Hash)
          next unless f.is_a?(Hash)

          field_name = f["field"]

          %w[visible_when disable_when].each do |cond_key|
            condition = f[cond_key]
            next unless condition.is_a?(Hash)

            condition = condition.transform_keys(&:to_s)
            next if condition.key?("service")

            cond_field = condition["field"]
            operator = condition["operator"]

            if cond_field && !target_field_names.include?(cond_field.to_s)
              @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}', " \
                         "nested field '#{field_name}', #{cond_key}: " \
                         "references unknown field '#{cond_field}' on target model '#{assoc.target_model}'"
            end

            if operator && !VALID_CONDITION_OPERATORS.include?(operator.to_s)
              @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}', " \
                         "nested field '#{field_name}', #{cond_key}: " \
                         "uses unknown operator '#{operator}'"
            end

            # Operator-type compatibility validation
            validate_operator_type_compatibility(
              "Presenter '#{presenter.name}'",
              "#{config_name} section '#{section_label}', nested field '#{field_name}', #{cond_key}",
              operator, assoc.target_model, cond_field
            )
          end
        end
      end

      # Validate field-level conditions in json_field nested_fields sections.
      # When target_model is specified, validates condition field references against it.
      def validate_json_field_conditions(presenter, section, config_name)
        target_model_name = section["target_model"]
        return unless target_model_name

        target_def = loader.model_definitions[target_model_name]
        return unless target_def

        target_field_names = target_def.fields.map(&:name)
        section_label = section["title"] || "(unnamed)"

        all_fields = section["fields"] || []
        (section["sub_sections"] || []).each do |ss|
          all_fields += (ss["fields"] || [])
        end

        all_fields.each do |f|
          f = f.transform_keys(&:to_s) if f.is_a?(Hash)
          next unless f.is_a?(Hash)

          field_name = f["field"]

          %w[visible_when disable_when].each do |cond_key|
            condition = f[cond_key]
            next unless condition.is_a?(Hash)

            condition = condition.transform_keys(&:to_s)
            next if condition.key?("service")

            cond_field = condition["field"]
            operator = condition["operator"]

            if cond_field && !target_field_names.include?(cond_field.to_s)
              @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}', " \
                         "nested field '#{field_name}', #{cond_key}: " \
                         "references unknown field '#{cond_field}' on target model '#{target_model_name}'"
            end

            if operator && !VALID_CONDITION_OPERATORS.include?(operator.to_s)
              @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}', " \
                         "nested field '#{field_name}', #{cond_key}: " \
                         "uses unknown operator '#{operator}'"
            end

            validate_operator_type_compatibility(
              "Presenter '#{presenter.name}'",
              "#{config_name} section '#{section_label}', nested field '#{field_name}', #{cond_key}",
              operator, target_model_name, cond_field
            )
          end
        end
      end

      def validate_presenter_scopes(presenter)
        search_config = presenter.search_config
        return unless search_config.is_a?(Hash)

        model_scopes = model_scope_names(presenter.model)
        filters = search_config["predefined_filters"] || []
        filters.each do |filter|
          filter = filter.transform_keys(&:to_s) if filter.is_a?(Hash)
          scope_name = filter["scope"] if filter.is_a?(Hash)
          next unless scope_name

          unless model_scopes.include?(scope_name.to_s)
            @errors << "Presenter '#{presenter.name}', search filter '#{filter['name']}': " \
                       "references unknown scope '#{scope_name}' on model '#{presenter.model}'"
          end
        end

        # Validate searchable fields
        searchable = search_config["searchable_fields"] || []
        valid_fields = model_field_names(presenter.model)
        searchable.each do |field_name|
          unless valid_fields.include?(field_name.to_s)
            @warnings << "Presenter '#{presenter.name}', searchable_fields: " \
                         "references unknown field '#{field_name}' on model '#{presenter.model}'"
          end
        end
      end

      def validate_presenter_advanced_filter(presenter)
        af_config = presenter.advanced_filter_config
        return if af_config.empty?

        model_def = loader.model_definitions[presenter.model]
        return unless model_def

        valid_fields = model_def.fields.map(&:name)
        valid_fields.concat(%w[created_at updated_at]) if model_def.timestamps?
        assoc_names = model_def.associations.map(&:name).map(&:to_s)

        # Validate mutual exclusion of filterable_fields and filterable_fields_except
        if af_config.key?("filterable_fields") && af_config.key?("filterable_fields_except")
          @errors << "Presenter '#{presenter.name}', advanced_filter: " \
                     "filterable_fields and filterable_fields_except are mutually exclusive"
        end

        # Validate filterable_fields_except
        (af_config["filterable_fields_except"] || []).each do |field_path|
          parts = field_path.to_s.split(".")
          if parts.size == 1
            unless valid_fields.include?(parts[0]) || assoc_names.include?(parts[0])
              @errors << "Presenter '#{presenter.name}', advanced_filter filterable_fields_except: " \
                         "references unknown field or association '#{field_path}' on model '#{presenter.model}'"
            end
          else
            unless assoc_names.include?(parts[0])
              @errors << "Presenter '#{presenter.name}', advanced_filter filterable_fields_except: " \
                         "references unknown association '#{parts[0]}' in path '#{field_path}'"
            end
          end
        end

        # Validate filterable_fields
        (af_config["filterable_fields"] || []).each do |field_path|
          parts = field_path.to_s.split(".")
          if parts.size == 1
            unless valid_fields.include?(parts[0])
              @errors << "Presenter '#{presenter.name}', advanced_filter filterable_fields: " \
                         "references unknown field '#{field_path}' on model '#{presenter.model}'"
            end
          else
            # Association path — validate first segment is a known association
            unless assoc_names.include?(parts[0])
              @errors << "Presenter '#{presenter.name}', advanced_filter filterable_fields: " \
                         "references unknown association '#{parts[0]}' in path '#{field_path}'"
            end
          end
        end

        # Validate field_options reference valid fields
        (af_config["field_options"] || {}).each_key do |field_name|
          filterable = af_config["filterable_fields"] || []
          all_known = valid_fields + filterable.map(&:to_s)
          unless all_known.include?(field_name.to_s)
            @warnings << "Presenter '#{presenter.name}', advanced_filter field_options: " \
                         "references unknown field '#{field_name}'"
          end
        end

        # Validate presets
        (af_config["presets"] || []).each do |preset|
          preset = preset.transform_keys(&:to_s) if preset.is_a?(Hash)
          unless preset["name"].present?
            @errors << "Presenter '#{presenter.name}', advanced_filter presets: " \
                       "preset is missing required 'name'"
          end
        end

        # Validate max_conditions is positive integer
        if af_config.key?("max_conditions")
          mc = af_config["max_conditions"]
          unless mc.is_a?(Integer) && mc > 0
            @errors << "Presenter '#{presenter.name}', advanced_filter: " \
                       "max_conditions must be a positive integer, got '#{mc}'"
          end
        end

        # Validate max_association_depth is 1-5
        if af_config.key?("max_association_depth")
          mad = af_config["max_association_depth"]
          unless mad.is_a?(Integer) && mad.between?(1, 5)
            @errors << "Presenter '#{presenter.name}', advanced_filter: " \
                       "max_association_depth must be between 1 and 5, got '#{mad}'"
          end
        end

        # Validate max_nesting_depth is 1-10
        if af_config.key?("max_nesting_depth")
          mnd = af_config["max_nesting_depth"]
          unless mnd.is_a?(Integer) && mnd.between?(1, 10)
            @errors << "Presenter '#{presenter.name}', advanced_filter: " \
                       "max_nesting_depth must be between 1 and 10, got '#{mnd}'"
          end
        end

        # Validate default_combinator
        if af_config.key?("default_combinator")
          dc = af_config["default_combinator"].to_s
          unless %w[and or].include?(dc)
            @errors << "Presenter '#{presenter.name}', advanced_filter: " \
                       "default_combinator must be 'and' or 'or', got '#{dc}'"
          end
        end

        # Validate custom_filters don't collide with model field names
        (af_config["custom_filters"] || []).each do |cf|
          cf_name = cf.is_a?(Hash) ? cf["name"].to_s : cf.to_s
          if valid_fields.include?(cf_name)
            @warnings << "Presenter '#{presenter.name}', advanced_filter custom_filters: " \
                         "'#{cf_name}' collides with model field name"
          end
        end

        # Validate saved_filters configuration
        validate_presenter_saved_filters(presenter, af_config)
      end

      def validate_presenter_saved_filters(presenter, af_config)
        sf_config = af_config["saved_filters"]
        return unless sf_config.is_a?(Hash) && sf_config["enabled"] == true

        # Warn if saved_filter model is not defined
        unless loader.model_definitions.key?("saved_filter")
          @warnings << "Presenter '#{presenter.name}': saved_filters.enabled is true " \
                       "but 'saved_filter' model is not defined. Run: rails generate lcp_ruby:saved_filters"
        end

        # Validate visibility_options
        if sf_config.key?("visibility_options")
          valid_vis = %w[personal role global group]
          Array(sf_config["visibility_options"]).each do |vis|
            unless valid_vis.include?(vis.to_s)
              @errors << "Presenter '#{presenter.name}', saved_filters: " \
                         "invalid visibility_option '#{vis}'. Valid: #{valid_vis.join(', ')}"
            end
          end

          # Warn if 'group' is in visibility_options but group_source is :none
          if Array(sf_config["visibility_options"]).include?("group") &&
             LcpRuby.configuration.group_source == :none
            @warnings << "Presenter '#{presenter.name}', saved_filters: " \
                         "visibility_options includes 'group' but group_source is :none"
          end
        end

        # Validate display mode
        if sf_config.key?("display")
          valid_displays = %w[inline dropdown sidebar]
          unless valid_displays.include?(sf_config["display"].to_s)
            @errors << "Presenter '#{presenter.name}', saved_filters: " \
                       "display must be one of: #{valid_displays.join(', ')}, got '#{sf_config['display']}'"
          end
        end

        # Validate numeric limits
        %w[max_per_user max_per_role max_global max_visible_pinned].each do |key|
          if sf_config.key?(key)
            val = sf_config[key]
            unless val.is_a?(Integer) && val > 0
              @errors << "Presenter '#{presenter.name}', saved_filters: " \
                         "#{key} must be a positive integer, got '#{val}'"
            end
          end
        end
      end

      def validate_presenter_default_sort(presenter, valid_fields)
        default_sort = presenter.index_config["default_sort"]
        return unless default_sort.is_a?(Hash)

        sort = default_sort.transform_keys(&:to_s)
        field = sort["field"]
        direction = sort["direction"]

        # Allow dot-path sort fields (validated at runtime via apply_sort)
        if field && !field.to_s.include?(".") && !valid_fields.include?(field.to_s)
          @errors << "Presenter '#{presenter.name}', index default_sort: " \
                     "references unknown field '#{field}' on model '#{presenter.model}'"
        end

        if direction && !VALID_SORT_DIRECTIONS.include?(direction.to_s)
          @errors << "Presenter '#{presenter.name}', index default_sort: " \
                     "invalid direction '#{direction}'. Valid: #{VALID_SORT_DIRECTIONS.join(', ')}"
        end
      end

      def validate_presenter_includes(presenter)
        assoc_names = model_association_names(presenter.model)

        %w[index_config show_config form_config].each do |config_method|
          config = presenter.send(config_method)
          next unless config.is_a?(Hash)

          config_label = config_method.sub("_config", "")
          %w[includes eager_load].each do |key|
            entries = config[key]
            next unless entries.is_a?(Array)

            entries.each do |entry|
              # Only validate simple string entries; skip deep hashes (too complex for static analysis)
              next unless entry.is_a?(String)

              unless assoc_names.include?(entry)
                @warnings << "Presenter '#{presenter.name}', #{config_label}.#{key}: " \
                             "references unknown association '#{entry}' on model '#{presenter.model}'"
              end
            end
          end
        end
      end

      def validate_presenter_actions(presenter)
        all_actions = (presenter.collection_actions + presenter.single_actions + presenter.batch_actions)
        all_actions.each do |action|
          action = action.transform_keys(&:to_s) if action.is_a?(Hash)
          next unless action.is_a?(Hash)

          validate_action_visible_when(presenter, action)
          validate_custom_action_name(presenter, action)
        end
      end

      def validate_custom_action_name(presenter, action)
        return unless action["type"].to_s == "custom"

        if BUILT_IN_ACTION_NAMES.include?(action["name"].to_s)
          @warnings << "Presenter '#{presenter.name}', action '#{action['name']}': " \
                       "custom action uses built-in name '#{action['name']}', likely misconfigured"
        end
      end

      def validate_action_visible_when(presenter, action)
        %w[visible_when disable_when].each do |cond_key|
          condition = action[cond_key]
          next unless condition.is_a?(Hash)

          validate_condition(presenter, condition, "action '#{action['name']}', #{cond_key}")
        end
      end

      # Recursively validates a condition tree (field, service, compound, collection).
      def validate_condition(presenter, condition, context, depth: 0)
        return unless condition.is_a?(Hash)

        if depth > ConditionEvaluator::MAX_NESTING_DEPTH
          @errors << "Presenter '#{presenter.name}', #{context}: condition nesting exceeds maximum depth of #{ConditionEvaluator::MAX_NESTING_DEPTH}"
          return
        end

        normalized = condition.transform_keys(&:to_s)

        if normalized.key?("all") || normalized.key?("any")
          key = normalized.key?("all") ? "all" : "any"
          children = normalized[key]
          unless children.is_a?(Array)
            @errors << "Presenter '#{presenter.name}', #{context}: '#{key}' must be an array"
            return
          end
          if children.empty?
            @warnings << "Presenter '#{presenter.name}', #{context}: empty '#{key}' condition list"
          end
          children.each_with_index do |child, i|
            validate_condition(presenter, child, "#{context} #{key}[#{i}]", depth: depth + 1)
          end
        elsif normalized.key?("not")
          child = normalized["not"]
          unless child.is_a?(Hash)
            @errors << "Presenter '#{presenter.name}', #{context}: 'not' must contain a single condition hash"
            return
          end
          validate_condition(presenter, child, "#{context} not", depth: depth + 1)
        elsif normalized.key?("collection")
          validate_collection_condition(presenter, normalized, context, depth: depth)
        elsif normalized.key?("service")
          # Service conditions are opaque — no further validation
        elsif normalized.key?("field")
          validate_field_condition(presenter, normalized, context)
        else
          @errors << "Presenter '#{presenter.name}', #{context}: " \
                     "condition must contain 'field', 'service', 'all', 'any', 'not', or 'collection' key"
        end
      end

      # Validates a flat field-value condition.
      def validate_field_condition(presenter, condition, context)
        field_name = condition["field"]
        operator = condition["operator"]

        model_def = loader.model_definitions[presenter.model]
        has_custom_fields = model_def&.custom_fields_enabled?

        if field_name
          if field_name.to_s.include?(".")
            validate_dot_path_field("Presenter '#{presenter.name}'", context, presenter.model, field_name.to_s)
          else
            valid_fields = model_all_field_names(presenter.model)
            unless valid_fields.include?(field_name.to_s) || has_custom_fields
              @errors << "Presenter '#{presenter.name}', #{context}: " \
                         "references unknown field '#{field_name}'"
            end
          end
        end

        if operator && !VALID_CONDITION_OPERATORS.include?(operator.to_s)
          @errors << "Presenter '#{presenter.name}', #{context}: " \
                     "uses unknown operator '#{operator}'"
        end

        if %w[matches not_matches].include?(operator.to_s) && condition["value"].is_a?(String)
          begin
            Regexp.new(condition["value"])
          rescue RegexpError => e
            @errors << "Presenter '#{presenter.name}', #{context}: " \
                       "invalid regex pattern '#{condition['value']}': #{e.message}"
          end
        end

        # Validate value references
        validate_value_reference("Presenter '#{presenter.name}'", context, condition["value"], presenter.model)

        # Operator-type compatibility (only for direct fields, not dot-paths)
        unless field_name.to_s.include?(".")
          validate_operator_type_compatibility(
            "Presenter '#{presenter.name}'", context, operator, presenter.model, field_name
          )
        end
      end

      # Validates a collection condition (has_many quantifier).
      def validate_collection_condition(presenter, condition, context, depth: 0)
        collection_name = condition["collection"].to_s
        quantifier = condition["quantifier"]&.to_s || "any"
        inner = condition["condition"]

        model_def = loader.model_definitions[presenter.model]
        unless model_def
          @errors << "Presenter '#{presenter.name}', #{context}: model '#{presenter.model}' not found"
          return
        end

        assoc = model_def.associations.find { |a| a.name == collection_name }
        unless assoc
          @errors << "Presenter '#{presenter.name}', #{context}: " \
                     "collection '#{collection_name}' is not a defined association"
          return
        end

        unless assoc.type.to_s == "has_many"
          @errors << "Presenter '#{presenter.name}', #{context}: " \
                     "collection '#{collection_name}' must be a has_many association (got #{assoc.type})"
        end

        unless %w[any all none].include?(quantifier)
          @errors << "Presenter '#{presenter.name}', #{context}: " \
                     "unknown quantifier '#{quantifier}' (expected: any, all, none)"
        end

        unless inner.is_a?(Hash)
          @errors << "Presenter '#{presenter.name}', #{context}: " \
                     "collection condition is missing inner 'condition'"
          return
        end

        # Validate inner condition against the target model
        if assoc.target_model && loader.model_definitions.key?(assoc.target_model)
          # Create a temporary presenter-like context for the target model
          target_presenter = ConditionValidationContext.new(presenter.name, assoc.target_model)
          validate_condition(target_presenter, inner, "#{context} collection('#{collection_name}')", depth: depth + 1)
        end
      end

      # Validates a dot-path field by walking the association chain.
      def validate_dot_path_field(source, context, model_name, field_path)
        segments = field_path.split(".")
        current_model = model_name

        segments.each_with_index do |segment, idx|
          model_def = loader.model_definitions[current_model]
          return unless model_def # Can't validate further

          if idx < segments.size - 1
            # Intermediate segment must be an association
            assoc = model_def.associations.find { |a| a.name == segment }
            unless assoc
              @errors << "#{source}, #{context}: dot-path '#{field_path}' — " \
                         "'#{segment}' is not a defined association on model '#{current_model}'"
              return
            end

            if assoc.type.to_s == "has_many"
              @errors << "#{source}, #{context}: dot-path '#{field_path}' — " \
                         "'#{segment}' is a has_many association. Use collection conditions instead."
              return
            end

            current_model = assoc.target_model
            return unless current_model
          else
            # Leaf segment must be a field (including FKs, userstamps, timestamps, aggregates)
            valid_fields = model_all_field_names(current_model)
            has_custom_fields = model_def.custom_fields_enabled?
            unless valid_fields.include?(segment) || has_custom_fields
              @errors << "#{source}, #{context}: dot-path '#{field_path}' — " \
                         "unknown field '#{segment}' on model '#{current_model}'"
            end
          end
        end
      end

      # Validates a value reference hash (field_ref, current_user, date, service).
      def validate_value_reference(source, context, value, model_name)
        return unless value.is_a?(Hash)

        normalized = value.transform_keys(&:to_s)

        if normalized.key?("field_ref")
          ref = normalized["field_ref"].to_s
          if ref.include?(".")
            validate_dot_path_field(source, "#{context} value field_ref", model_name, ref)
          else
            valid_fields = model_all_field_names(model_name)
            model_def = loader.model_definitions[model_name]
            has_custom_fields = model_def&.custom_fields_enabled?
            unless valid_fields.include?(ref) || has_custom_fields
              @errors << "#{source}, #{context}: value field_ref '#{ref}' — unknown field on model '#{model_name}'"
            end
          end
        elsif normalized.key?("lookup")
          validate_lookup_reference(source, context, normalized, model_name)
        elsif normalized.key?("date")
          unless %w[today now].include?(normalized["date"].to_s)
            @errors << "#{source}, #{context}: unknown date reference '#{normalized['date']}' (expected: today, now)"
          end
        elsif normalized.key?("service")
          service_key = normalized["service"].to_s
          unless ConditionServiceRegistry.registered?(service_key)
            @warnings << "#{source}, #{context}: value service '#{service_key}' is not registered"
          end
        end
      end

      def validate_lookup_reference(source, context, normalized, model_name)
        lookup_model = normalized["lookup"].to_s
        match = normalized["match"]
        pick = normalized["pick"]

        unless model_names.include?(lookup_model)
          @errors << "#{source}, #{context}: lookup references unknown model '#{lookup_model}'"
          return
        end

        unless match.is_a?(Hash)
          @errors << "#{source}, #{context}: lookup 'match' must be a hash"
          return
        end

        unless pick.is_a?(String) && pick.present?
          @errors << "#{source}, #{context}: lookup 'pick' must be a non-empty string"
          return
        end

        target_fields = model_all_field_names(lookup_model)

        # Validate pick field exists on target model
        unless target_fields.include?(pick)
          @errors << "#{source}, #{context}: lookup 'pick' field '#{pick}' does not exist on model '#{lookup_model}'"
        end

        # Validate match keys exist on target model and validate match values
        match.transform_keys(&:to_s).each do |key, val|
          unless target_fields.include?(key)
            @errors << "#{source}, #{context}: lookup 'match' key '#{key}' does not exist on model '#{lookup_model}'"
          end

          next unless val.is_a?(Hash)

          val_normalized = val.transform_keys(&:to_s)
          if val_normalized.key?("lookup")
            @errors << "#{source}, #{context}: nested lookup value references are not supported"
          else
            validate_value_reference(source, "#{context} lookup match '#{key}'", val, model_name)
          end
        end
      end

      def validate_operator_type_compatibility(source, context, operator, model_name, field_name)
        return unless operator && field_name

        field_def = model_field_definition(model_name, field_name)
        return unless field_def # Unknown field — already reported or skipped

        if field_def.type_definition
          resolved_type = field_def.type_definition.base_type
          return unless resolved_type.present? # Custom type without base_type — can't validate
        else
          resolved_type = field_def.type
        end

        if NUMERIC_OPERATORS.include?(operator.to_s) && !NUMERIC_TYPES.include?(resolved_type)
          @errors << "#{source}, #{context}: " \
                     "operator '#{operator}' is not compatible with field '#{field_name}' " \
                     "(type '#{resolved_type}'). Numeric operators require: #{NUMERIC_TYPES.join(', ')}"
        end

        if REGEX_OPERATORS.include?(operator.to_s) && !TEXT_TYPES.include?(resolved_type)
          @errors << "#{source}, #{context}: " \
                     "operator '#{operator}' is not compatible with field '#{field_name}' " \
                     "(type '#{resolved_type}'). Regex operators require: #{TEXT_TYPES.join(', ')}"
        end

        if STRING_OPERATORS.include?(operator.to_s) && !TEXT_TYPES.include?(resolved_type) && resolved_type != "array"
          @errors << "#{source}, #{context}: " \
                     "operator '#{operator}' is not compatible with field '#{field_name}' " \
                     "(type '#{resolved_type}'). String operators require: #{TEXT_TYPES.join(', ')}"
        end
      end

      # --- Permission validations ---

      def validate_permissions
        loader.permission_definitions.each_value do |perm|
          next if perm.default?

          validate_permission_model(perm)
          validate_permission_roles(perm)
          validate_permission_field_overrides(perm)
          validate_permission_record_rules(perm)
          validate_permission_presenter_refs(perm)
        end
      end

      def validate_permission_model(perm)
        unless model_names.include?(perm.model)
          @errors << "Permission for '#{perm.model}': references unknown model"
        end
      end

      def validate_permission_roles(perm)
        perm.roles.each do |role_name, config|
          config = config.transform_keys(&:to_s) if config.is_a?(Hash)
          next unless config.is_a?(Hash)

          validate_permission_crud(perm, role_name, config)
          validate_permission_fields(perm, role_name, config)
        end
      end

      def validate_permission_crud(perm, role_name, config)
        crud = config["crud"]
        return unless crud.is_a?(Array)

        crud.each do |action|
          unless VALID_CRUD_ACTIONS.include?(action.to_s)
            @errors << "Permission '#{perm.model}', role '#{role_name}': " \
                       "unknown CRUD action '#{action}'. Valid: #{VALID_CRUD_ACTIONS.join(', ')}"
          end
        end
      end

      def validate_permission_fields(perm, role_name, config)
        fields_config = config["fields"]
        return unless fields_config.is_a?(Hash)

        valid_fields = model_field_names(perm.model)
        return if valid_fields.empty? # Model may not exist (caught elsewhere)

        model_def = loader.model_definitions[perm.model]
        has_custom_fields = model_def&.custom_fields_enabled?

        %w[readable writable].each do |access|
          field_list = fields_config[access]
          next if field_list.nil? || field_list == "all" || field_list == []

          next unless field_list.is_a?(Array)

          field_list.each do |fname|
            # FK fields like company_id and polymorphic type fields like commentable_type
            # are valid in writable but not in model fields
            next if fname.to_s.end_with?("_id")
            next if fname.to_s.end_with?("_type")
            # Skip custom_data aggregate permission
            next if fname.to_s == "custom_data" && has_custom_fields
            # Skip unknown fields on models with custom_fields (could be custom field names)
            next if has_custom_fields && !valid_fields.include?(fname.to_s)

            unless valid_fields.include?(fname.to_s)
              @warnings << "Permission '#{perm.model}', role '#{role_name}': " \
                           "#{access} field '#{fname}' not found in model fields"
            end
          end
        end
      end

      def validate_permission_field_overrides(perm)
        valid_fields = model_field_names(perm.model)
        return if valid_fields.empty?

        model_def = loader.model_definitions[perm.model]
        has_custom_fields = model_def&.custom_fields_enabled?

        perm.field_overrides.each_key do |field_name|
          # Skip unknown fields on models with custom_fields (could be custom field names)
          next if has_custom_fields && !valid_fields.include?(field_name.to_s)

          unless valid_fields.include?(field_name.to_s)
            @warnings << "Permission '#{perm.model}': field_override for " \
                         "unknown field '#{field_name}'"
          end
        end
      end

      def validate_permission_record_rules(perm)
        perm.record_rules.each do |rule|
          rule = rule.transform_keys(&:to_s) if rule.is_a?(Hash)
          next unless rule.is_a?(Hash)

          condition = rule["condition"]
          if condition.is_a?(Hash)
            # Reuse the recursive condition validation with a presenter-like context
            perm_presenter = ConditionValidationContext.new(perm.model, perm.model)
            validate_condition(perm_presenter, condition, "record rule '#{rule['name']}', condition")
          end

          # Validate deny_crud values
          effect = rule["effect"]
          if effect.is_a?(Hash)
            deny_crud = effect["deny_crud"] || []
            deny_crud.each do |action|
              unless VALID_CRUD_ACTIONS.include?(action.to_s)
                @errors << "Permission '#{perm.model}', record rule '#{rule['name']}': " \
                           "deny_crud contains unknown action '#{action}'"
              end
            end

            # Validate except_roles reference defined roles
            except_roles = effect["except_roles"] || []
            defined_roles = perm.roles.keys.map(&:to_s)
            except_roles.each do |role|
              unless defined_roles.include?(role.to_s)
                @warnings << "Permission '#{perm.model}', record rule '#{rule['name']}': " \
                             "except_roles references undefined role '#{role}'"
              end
            end
          end
        end
      end

      def validate_permission_presenter_refs(perm)
        presenter_names = loader.presenter_definitions.keys

        perm.roles.each do |role_name, config|
          config = config.transform_keys(&:to_s) if config.is_a?(Hash)
          next unless config.is_a?(Hash)

          presenters = config["presenters"]
          next if presenters.nil? || presenters == "all"
          next unless presenters.is_a?(Array)

          presenters.each do |pname|
            unless presenter_names.include?(pname.to_s)
              @errors << "Permission '#{perm.model}', role '#{role_name}': " \
                         "references unknown presenter '#{pname}'"
            end
          end
        end
      end

      # --- View group validations ---

      def validate_view_groups
        return unless loader.respond_to?(:view_group_definitions)

        presenter_in_groups = {}
        positions = {}

        loader.view_group_definitions.each_value do |vg|
          unless model_names.include?(vg.model)
            @errors << "View group '#{vg.name}': references unknown model '#{vg.model}'"
          end

          presenter_names = loader.presenter_definitions.keys
          vg.presenter_names.each do |pname|
            unless presenter_names.include?(pname)
              @errors << "View group '#{vg.name}': references unknown presenter '#{pname}'"
            end

            if presenter_in_groups.key?(pname)
              @errors << "Presenter '#{pname}' appears in multiple view groups: " \
                         "'#{presenter_in_groups[pname]}' and '#{vg.name}'"
            end
            presenter_in_groups[pname] = vg.name
          end

          unless vg.presenter_names.include?(vg.primary_presenter)
            @errors << "View group '#{vg.name}': primary presenter '#{vg.primary_presenter}' " \
                       "is not in the views list"
          end

          validate_breadcrumb_relation(vg)
          validate_switcher_config(vg)

          next unless vg.navigable?

          pos = vg.navigation_config["position"]
          if pos
            if positions.key?(pos)
              @warnings << "View group '#{vg.name}': navigation position #{pos} " \
                           "is also used by view group '#{positions[pos]}'"
            end
            positions[pos] = vg.name
          end
        end
      end

      def validate_switcher_config(vg)
        config = vg.switcher_config
        return if config == :auto || config == false

        return unless config.is_a?(Array)

        invalid = config - ViewGroupDefinition::VALID_SWITCHER_CONTEXTS
        if invalid.any?
          @errors << "View group '#{vg.name}': invalid switcher contexts: #{invalid.join(', ')}. " \
                     "Valid contexts are: #{ViewGroupDefinition::VALID_SWITCHER_CONTEXTS.join(', ')}"
        end
      end

      def validate_breadcrumb_relation(vg)
        relation = vg.breadcrumb_relation
        return unless relation

        model_def = loader.model_definitions[vg.model]
        return unless model_def

        assoc_names = model_association_names(vg.model)
        unless assoc_names.include?(relation)
          @errors << "View group '#{vg.name}': breadcrumb relation '#{relation}' " \
                     "does not match any association on model '#{vg.model}'. " \
                     "Available associations: #{assoc_names.join(', ')}"
        end
      end

      # --- Uniqueness validations ---

      def validate_uniqueness
        validate_slug_uniqueness
        validate_table_name_uniqueness
      end

      def validate_slug_uniqueness
        slugs = {}
        loader.presenter_definitions.each_value do |presenter|
          next unless presenter.slug.present?

          if slugs.key?(presenter.slug)
            @errors << "Duplicate slug '#{presenter.slug}': used by presenters " \
                       "'#{slugs[presenter.slug]}' and '#{presenter.name}'"
          else
            slugs[presenter.slug] = presenter.name
          end
        end
      end

      def validate_table_name_uniqueness
        tables = {}
        loader.model_definitions.each_value do |model|
          if tables.key?(model.table_name)
            @errors << "Duplicate table_name '#{model.table_name}': used by models " \
                       "'#{tables[model.table_name]}' and '#{model.name}'"
          else
            tables[model.table_name] = model.name
          end
        end
      end

      # --- Menu validations ---

      def validate_menu
        return unless loader.respond_to?(:menu_definition)

        menu_def = loader.menu_definition
        return unless menu_def

        all_roles = collect_all_defined_roles

        validate_menu_items(menu_def.top_menu, all_roles) if menu_def.has_top_menu?
        validate_menu_items(menu_def.sidebar_menu, all_roles) if menu_def.has_sidebar_menu?
      end

      # View group references are already validated by Loader.validate_menu_references! at load time.
      # This method only validates role references in visible_when conditions.
      def validate_menu_items(items, all_roles)
        items.each do |item|
          if item.has_role_constraint?
            item.allowed_roles.each do |role|
              unless all_roles.include?(role.to_s)
                @warnings << "Menu item '#{item.label || item.view_group_name}': " \
                             "visible_when references undefined role '#{role}'"
              end
            end
          end

          validate_menu_items(item.children, all_roles) if item.group?
        end
      end

      def collect_all_defined_roles
        loader.permission_definitions.each_with_object([]) do |(_, perm), roles|
          perm.roles.each_key { |r| roles << r.to_s }
        end.uniq
      end

      # --- Role model validations ---

      def validate_role_model
        return unless LcpRuby.configuration.role_source == :model

        role_model_name = LcpRuby.configuration.role_model
        unless model_names.include?(role_model_name)
          @errors << "role_source is :model but model '#{role_model_name}' is not defined"
          return
        end

        model_def = loader.model_definitions[role_model_name]
        result = Roles::ContractValidator.validate(model_def)
        result.errors.each { |e| @errors << e }
        result.warnings.each { |w| @warnings << w }
      end

      # --- Permission source model validations ---

      def validate_permission_source_model
        return unless LcpRuby.configuration.permission_source == :model

        perm_model_name = LcpRuby.configuration.permission_model
        unless model_names.include?(perm_model_name)
          @errors << "permission_source is :model but model '#{perm_model_name}' is not defined"
          return
        end

        model_def = loader.model_definitions[perm_model_name]
        result = Permissions::ContractValidator.validate(model_def)
        result.errors.each { |e| @errors << e }
        result.warnings.each { |w| @warnings << w }
      end

      # --- Group model validations ---

      def validate_group_models
        return unless LcpRuby.configuration.group_source == :model

        config = LcpRuby.configuration

        # Validate group model
        if model_names.include?(config.group_model)
          group_def = loader.model_definitions[config.group_model]
          result = Groups::ContractValidator.validate_group(group_def)
          result.errors.each { |e| @errors << e }
          result.warnings.each { |w| @warnings << w }
        else
          @errors << "group_source is :model but group model '#{config.group_model}' is not defined"
        end

        # Validate membership model
        if model_names.include?(config.group_membership_model)
          membership_def = loader.model_definitions[config.group_membership_model]
          result = Groups::ContractValidator.validate_membership(membership_def)
          result.errors.each { |e| @errors << e }
          result.warnings.each { |w| @warnings << w }
        else
          @errors << "group_source is :model but group membership model '#{config.group_membership_model}' is not defined"
        end

        # Validate role mapping model (optional)
        if config.group_role_mapping_model
          if model_names.include?(config.group_role_mapping_model)
            mapping_def = loader.model_definitions[config.group_role_mapping_model]
            result = Groups::ContractValidator.validate_role_mapping(mapping_def)
            result.errors.each { |e| @errors << e }
            result.warnings.each { |w| @warnings << w }
          else
            @errors << "group_source is :model but group role mapping model '#{config.group_role_mapping_model}' is not defined"
          end
        end
      end

      # --- Custom fields validations ---

      def validate_custom_fields
        cf_models = loader.model_definitions.values.select(&:custom_fields_enabled?)
        return if cf_models.empty?

        unless loader.model_definitions.key?("custom_field_definition")
          @errors << "One or more models have custom_fields enabled " \
                     "(#{cf_models.map(&:name).join(', ')}), but the 'custom_field_definition' model " \
                     "is not defined. Run `rails generate lcp_ruby:custom_fields` to generate it."
          return
        end

        cfd_def = loader.model_definitions["custom_field_definition"]
        result = CustomFields::ContractValidator.validate(cfd_def)
        result.errors.each { |e| @errors << e }
        result.warnings.each { |w| @warnings << w }
      end
    end
  end
end
