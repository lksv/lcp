module LcpRuby
  module Permissions
    class ChangeHandler
      def self.install!(model_class)
        fields = LcpRuby.configuration.permission_model_fields.transform_keys(&:to_s)
        target_model_field = fields["target_model"]

        model_class.after_commit do |record|
          model_name_value = record.public_send(target_model_field)
          if model_name_value.present?
            Registry.reload!(model_name_value)
          else
            Registry.reload!
          end

          # Policies capture perm_def in closures - must clear on any DB change
          Authorization::PolicyFactory.clear!
        end
      end
    end
  end
end
