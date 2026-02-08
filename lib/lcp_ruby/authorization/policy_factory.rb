module LcpRuby
  module Authorization
    class PolicyFactory
      class << self
        def policy_for(model_name)
          policies[model_name.to_s] ||= build_policy(model_name)
        end

        def clear!
          @policies = {}
        end

        private

        def policies
          @policies ||= {}
        end

        def build_policy(model_name)
          perm_def = load_permission_definition(model_name)

          policy_class = Class.new do
            attr_reader :user, :record

            define_method(:initialize) do |user, record|
              @user = user
              @record = record
              @evaluator = PermissionEvaluator.new(perm_def, user, model_name)
            end

            define_method(:index?) { @evaluator.can?(:index) }
            define_method(:show?) { @evaluator.can_for_record?(:show, record) }
            define_method(:create?) { @evaluator.can?(:create) }
            define_method(:new?) { create? }
            define_method(:update?) { @evaluator.can_for_record?(:update, record) }
            define_method(:edit?) { update? }
            define_method(:destroy?) { @evaluator.can_for_record?(:destroy, record) }

            define_method(:permitted_attributes_for_create) { @evaluator.writable_fields.map(&:to_sym) }
            define_method(:permitted_attributes_for_update) { @evaluator.writable_fields.map(&:to_sym) }

            define_method(:evaluator) { @evaluator }

            # Pundit scope
            scope_class = Class.new do
              attr_reader :user, :scope

              define_method(:initialize) do |user, scope|
                @user = user
                @scope = scope
                @evaluator = PermissionEvaluator.new(perm_def, user, model_name)
              end

              define_method(:resolve) do
                @evaluator.apply_scope(scope)
              end
            end

            const_set(:Scope, scope_class)
          end

          policy_class
        end

        def load_permission_definition(model_name)
          LcpRuby.loader.permission_definition(model_name)
        rescue MetadataError
          # If no specific permissions, return a permissive default
          PermissionDefinition.new(
            model: model_name,
            roles: {
              "admin" => {
                "crud" => %w[index show create update destroy],
                "fields" => { "readable" => "all", "writable" => "all" },
                "actions" => "all",
                "scope" => "all",
                "presenters" => "all"
              }
            },
            default_role: "admin"
          )
        end
      end
    end
  end
end
