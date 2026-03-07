module LcpRuby
  module DataSource
    # Boot-time setup for API-backed data sources.
    # Called from Engine.load_metadata! after model registration.
    module Setup
      def self.apply!(loader)
        any_api = loader.model_definitions.values.any?(&:api_model?)
        return unless any_api

        loader.model_definitions.each_value do |model_def|
          next unless model_def.api_model?

          model_class = LcpRuby.registry.model_for(model_def.name)
          next unless model_class

          adapter = build_adapter(model_def)
          model_class.lcp_data_source = adapter
          Registry.register(model_def.name, adapter)
        end

        Registry.mark_available!

        # Apply cross-source associations after all data sources are attached
        ModelFactory::ApiAssociationApplicator.new(loader).apply!
      end

      def self.build_adapter(model_def)
        config = model_def.data_source_config

        # Build the core adapter
        adapter = case model_def.data_source_type
        when :rest_json
          RestJson.new(config, model_def)
        when :host
          Host.new(config, model_def)
        else
          raise MetadataError, "Unknown data source type '#{config['type']}' for model '#{model_def.name}'"
        end

        # Wrap with caching if configured
        cache_config = config["cache"]
        if cache_config
          adapter = CachedWrapper.new(
            adapter,
            model_name: model_def.name,
            ttl: cache_config["ttl"] || 300,
            list_ttl: cache_config["list_ttl"] || 60,
            stale_on_error: cache_config.fetch("stale_on_error", true)
          )
        end

        # Wrap with resilience (always outermost)
        ResilientWrapper.new(adapter, model_name: model_def.name)
      end
    end
  end
end
