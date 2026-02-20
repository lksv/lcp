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
      VALID_CONDITION_OPERATORS = %w[eq not_eq neq in not_in gt gte lt lte present blank matches not_matches].freeze
      BUILT_IN_ACTION_NAMES = %w[show edit destroy create update].freeze
      VALID_SORT_DIRECTIONS = %w[asc desc].freeze

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
        validate_view_groups
        validate_menu
        validate_custom_fields
        validate_role_model

        ValidationResult.new(errors: @errors.dup, warnings: @warnings.dup)
      end

      private

      # Built-in models that are auto-created at runtime and not defined in user YAML.
      BUILT_IN_MODEL_NAMES = %w[custom_field_definition].freeze

      def model_names
        @model_names ||= loader.model_definitions.keys + BUILT_IN_MODEL_NAMES
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

      def model_association_names(model_name)
        definition = loader.model_definitions[model_name]
        return [] unless definition

        definition.associations.map(&:name)
      end

      # --- Model validations ---

      def validate_models
        loader.model_definitions.each_value do |model|
          validate_model_fields(model)
          validate_model_scopes(model)
          validate_model_events(model)
          validate_display_templates(model)
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
          .flat_map { |a|
            cols = [ a.foreign_key.to_s ]
            cols << "#{a.name}_type" if a.polymorphic
            cols
          }
        # has_many :through associations expose *_ids accessor (e.g., tag_ids for has_many :tags)
        collection_id_fields = model_def.associations
          .select { |a| a.through? }
          .map { |a| "#{a.name.to_s.singularize}_ids" }
        all_valid = valid_fields + fk_fields + collection_id_fields + %w[created_at updated_at id]

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

          # Validate association reference for nested_fields and association_list sections
          if %w[nested_fields association_list].include?(section_type)
            validate_section_association(presenter, section, config_name)
            next # Fields belong to the associated model — skip field-level validation
          end

          # Validate section-level conditions
          %w[visible_when disable_when].each do |cond_key|
            condition = section[cond_key]
            next unless condition.is_a?(Hash)

            validate_condition(presenter, condition, "#{config_name} section '#{section['title']}', #{cond_key}")
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

      def validate_section_association(presenter, section, config_name)
        assoc_name = section["association"]
        return unless assoc_name

        assoc_names = model_association_names(presenter.model)
        unless assoc_names.include?(assoc_name.to_s)
          section_label = section["title"] || section["section"] || "(unnamed)"
          @errors << "Presenter '#{presenter.name}', #{config_name} section '#{section_label}': " \
                     "#{section['type']} references unknown association '#{assoc_name}' on model '#{presenter.model}'"
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

      def validate_presenter_default_sort(presenter, valid_fields)
        default_sort = presenter.index_config["default_sort"]
        return unless default_sort.is_a?(Hash)

        sort = default_sort.transform_keys(&:to_s)
        field = sort["field"]
        direction = sort["direction"]

        if field && !valid_fields.include?(field.to_s)
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

      def validate_condition(presenter, condition, context)
        condition = condition.transform_keys(&:to_s)

        # Service conditions don't need field/operator validation
        return if condition.key?("service")

        field_name = condition["field"]
        operator = condition["operator"]

        if field_name
          valid_fields = model_field_names(presenter.model)
          unless valid_fields.include?(field_name.to_s)
            @errors << "Presenter '#{presenter.name}', #{context}: " \
                       "references unknown field '#{field_name}'"
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
            # FK fields like company_id and polymorphic type fields like commentable_type
            # are valid in writable but not in model fields
            next if fname.to_s.end_with?("_id")
            next if fname.to_s.end_with?("_type")

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

      def validate_breadcrumb_relation(vg)
        relation = vg.breadcrumb_relation
        return unless relation

        model_def = loader.model_definitions[vg.model]
        return unless model_def

        assoc_names = model_def.associations.map(&:name)
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

      # --- Custom fields validations ---

      def validate_custom_fields
        # The custom_data column is auto-added at runtime by SchemaManager
        # when custom_fields: true is set, so no explicit field declaration
        # is required in the model definition.
      end
    end
  end
end
