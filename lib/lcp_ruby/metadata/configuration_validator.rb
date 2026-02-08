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

      VALID_CRUD_ACTIONS = %w[index show create update destroy].freeze
      VALID_CONDITION_OPERATORS = %w[eq not_eq neq in not_in gt gte lt lte present blank].freeze

      attr_reader :loader

      def initialize(loader)
        @loader = loader
        @errors = []
        @warnings = []
      end

      def validate
        @errors = []
        @warnings = []

        validate_models
        validate_associations
        validate_presenters
        validate_permissions
        validate_uniqueness

        ValidationResult.new(errors: @errors.dup, warnings: @warnings.dup)
      end

      private

      def model_names
        @model_names ||= loader.model_definitions.keys
      end

      def model_field_names(model_name)
        definition = loader.model_definitions[model_name]
        return [] unless definition

        definition.fields.map(&:name)
      end

      def model_scope_names(model_name)
        definition = loader.model_definitions[model_name]
        return [] unless definition

        definition.scopes.map { |s| s.is_a?(Hash) ? (s["name"] || s[:name]).to_s : s.to_s }
      end

      # --- Model validations ---

      def validate_models
        loader.model_definitions.each_value do |model|
          validate_model_fields(model)
          validate_model_scopes(model)
          validate_model_events(model)
        end
      end

      def validate_model_fields(model)
        model.fields.each do |field|
          validate_enum_field(model, field) if field.enum?
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

          validate_scope_fields(model, scope_name, scope["where"])
          validate_scope_fields(model, scope_name, scope["where_not"])
          validate_scope_order_fields(model, scope_name, scope["order"])
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

        validate_association_foreign_key(model, assoc) if assoc.type == "belongs_to"
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
          validate_presenter_actions(presenter)
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
          .map { |a| a.foreign_key.to_s }
        all_valid = valid_fields + fk_fields + %w[created_at updated_at id]

        # Check table columns
        presenter.table_columns.each do |col|
          col = col.transform_keys(&:to_s) if col.is_a?(Hash)
          field_name = col.is_a?(Hash) ? col["field"] : col.to_s
          next unless field_name

          unless all_valid.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', table_columns: " \
                       "references unknown field '#{field_name}' on model '#{presenter.model}'"
          end
        end

        # Check form fields
        validate_presenter_section_fields(presenter, presenter.form_config, "form", all_valid)
        # Check show fields
        validate_presenter_section_fields(presenter, presenter.show_config, "show", all_valid)
      end

      def validate_presenter_section_fields(presenter, config, config_name, valid_fields)
        sections = config["sections"] || config["layout"] || []
        sections.each do |section|
          section = section.transform_keys(&:to_s) if section.is_a?(Hash)
          fields = section["fields"] || [] if section.is_a?(Hash)
          next unless fields

          fields.each do |f|
            f = f.transform_keys(&:to_s) if f.is_a?(Hash)
            field_name = f.is_a?(Hash) ? f["field"] : f.to_s
            next unless field_name

            unless valid_fields.include?(field_name.to_s)
              @errors << "Presenter '#{presenter.name}', #{config_name}: " \
                         "references unknown field '#{field_name}' on model '#{presenter.model}'"
            end
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

      def validate_presenter_actions(presenter)
        all_actions = (presenter.collection_actions + presenter.single_actions + presenter.batch_actions)
        all_actions.each do |action|
          action = action.transform_keys(&:to_s) if action.is_a?(Hash)
          next unless action.is_a?(Hash)

          validate_action_visible_when(presenter, action)
        end
      end

      def validate_action_visible_when(presenter, action)
        condition = action["visible_when"]
        return unless condition.is_a?(Hash)

        condition = condition.transform_keys(&:to_s)
        field_name = condition["field"]
        operator = condition["operator"]

        if field_name
          valid_fields = model_field_names(presenter.model)
          unless valid_fields.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', action '#{action['name']}': " \
                       "visible_when references unknown field '#{field_name}'"
          end
        end

        if operator && !VALID_CONDITION_OPERATORS.include?(operator.to_s)
          @errors << "Presenter '#{presenter.name}', action '#{action['name']}': " \
                     "visible_when uses unknown operator '#{operator}'"
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

        %w[readable writable].each do |access|
          field_list = fields_config[access]
          next if field_list.nil? || field_list == "all" || field_list == []

          next unless field_list.is_a?(Array)

          field_list.each do |fname|
            # FK fields like company_id are valid in writable but not in model fields
            next if fname.to_s.end_with?("_id")

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

        perm.field_overrides.each_key do |field_name|
          unless valid_fields.include?(field_name.to_s)
            @warnings << "Permission '#{perm.model}': field_override for " \
                         "unknown field '#{field_name}'"
          end
        end
      end

      def validate_permission_record_rules(perm)
        valid_fields = model_field_names(perm.model)

        perm.record_rules.each do |rule|
          rule = rule.transform_keys(&:to_s) if rule.is_a?(Hash)
          next unless rule.is_a?(Hash)

          condition = rule["condition"]
          next unless condition.is_a?(Hash)

          condition = condition.transform_keys(&:to_s)
          field_name = condition["field"]
          operator = condition["operator"]

          if field_name && valid_fields.any? && !valid_fields.include?(field_name.to_s)
            @errors << "Permission '#{perm.model}', record rule '#{rule['name']}': " \
                       "condition references unknown field '#{field_name}'"
          end

          if operator && !VALID_CONDITION_OPERATORS.include?(operator.to_s)
            @errors << "Permission '#{perm.model}', record rule '#{rule['name']}': " \
                       "condition uses unknown operator '#{operator}'"
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
    end
  end
end
