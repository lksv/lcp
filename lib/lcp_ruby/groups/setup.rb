module LcpRuby
  module Groups
    module Setup
      # Boot-time setup for the groups subsystem.
      # Called after models are built and permissions are set up.
      #
      # @param loader [LcpRuby::Metadata::Loader] the metadata loader instance
      def self.apply!(loader)
        source = LcpRuby.configuration.group_source
        return if source == :none

        case source
        when :yaml  then setup_yaml!(loader)
        when :model then setup_model!(loader)
        when :host  then setup_host!
        end
      end

      class << self
        private

        def setup_yaml!(loader)
          yaml_loader = YamlLoader.new
          yaml_loader.load(LcpRuby.configuration.metadata_path)

          Registry.set_loader(yaml_loader)
          Registry.mark_available!
        end

        def setup_model!(loader)
          config = LcpRuby.configuration

          # Validate group model
          validate_model!(loader, config.group_model, "group", "groups")
          # Validate membership model
          validate_model!(loader, config.group_membership_model, "group membership", "groups")

          # Validate group model contract
          group_def = loader.model_definitions[config.group_model]
          result = ContractValidator.validate_group(group_def)
          raise_contract_error!(config.group_model, result) unless result.valid?
          log_warnings(result)

          # Validate membership model contract
          membership_def = loader.model_definitions[config.group_membership_model]
          result = ContractValidator.validate_membership(membership_def)
          raise_contract_error!(config.group_membership_model, result) unless result.valid?
          log_warnings(result)

          # Validate role mapping model if configured
          if config.group_role_mapping_model
            validate_model!(loader, config.group_role_mapping_model, "group role mapping", "groups")
            mapping_def = loader.model_definitions[config.group_role_mapping_model]
            result = ContractValidator.validate_role_mapping(mapping_def)
            raise_contract_error!(config.group_role_mapping_model, result) unless result.valid?
            log_warnings(result)
          end

          # Set up loader and registry
          model_loader = ModelLoader.new
          Registry.set_loader(model_loader)
          Registry.mark_available!

          # Install change handlers
          group_class = LcpRuby.registry.model_for(config.group_model)
          membership_class = LcpRuby.registry.model_for(config.group_membership_model)
          mapping_class = config.group_role_mapping_model ? LcpRuby.registry.model_for(config.group_role_mapping_model) : nil

          ChangeHandler.install!(group_class, membership_class, mapping_class)
        end

        def setup_host!
          adapter = LcpRuby.configuration.group_adapter

          unless adapter
            message = "group_source is :host but no group_adapter is configured"
            if LcpRuby.generator_context?
              log_warn(message)
              return
            end
            raise MetadataError, message
          end

          %i[all_group_names groups_for_user roles_for_group].each do |method|
            unless adapter.respond_to?(method)
              raise MetadataError, "group_adapter must respond to ##{method}"
            end
          end

          host_loader = HostLoader.new(adapter)
          Registry.set_loader(host_loader)
          Registry.mark_available!
        end

        def validate_model!(loader, model_name, label, generator_name)
          model_def = loader.model_definitions[model_name]
          return if model_def

          message = "group_source is :model but #{label} model '#{model_name}' is not defined. " \
                    "Define it in your models YAML or run: rails generate lcp_ruby:#{generator_name}"

          if LcpRuby.generator_context?
            log_warn(message)
            return
          end

          raise MetadataError, message
        end

        def raise_contract_error!(model_name, result)
          raise MetadataError, "Model '#{model_name}' does not satisfy the group contract:\n" \
                               "#{result.errors.map { |e| "  - #{e}" }.join("\n")}"
        end

        def log_warnings(result)
          result.warnings.each do |warning|
            log_warn(warning)
          end
        end

        def log_warn(message)
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.warn("[LcpRuby::Groups] #{message}")
          end
        end
      end
    end
  end
end
