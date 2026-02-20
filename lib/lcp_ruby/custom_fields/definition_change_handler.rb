module LcpRuby
  module CustomFields
    class DefinitionChangeHandler
      def self.install!(model_class)
        model_class.after_commit do |record|
          target_model_name = record.target_model
          next if target_model_name.blank?

          Registry.reload!(target_model_name)

          begin
            target = LcpRuby.registry.model_for(target_model_name)
            target.apply_custom_field_accessors!
          rescue LcpRuby::Error => e
            Rails.logger.warn("[LcpRuby::CustomFields] Cache reload failed for '#{target_model_name}': #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
          end
        end
      end
    end
  end
end
