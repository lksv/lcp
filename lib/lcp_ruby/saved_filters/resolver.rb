module LcpRuby
  module SavedFilters
    class Resolver
      class << self
        # Returns visible saved filters for the current user on the given presenter.
        #
        # Union of:
        #   - personal filters (owner_id = user.id)
        #   - role filters (target_role matches user's role)
        #   - group filters (target_group in user's groups)
        #   - global filters
        #
        # @param presenter_slug [String]
        # @param user [Object] current user
        # @param evaluator [Authorization::PermissionEvaluator]
        # @return [Array<ActiveRecord::Base>]
        def visible_filters(presenter_slug:, user:, evaluator:)
          return [] unless Registry.available?

          model_class = Registry.model_class
          return [] unless model_class

          scope = model_class.where(target_presenter: presenter_slug)

          # Build OR conditions for visibility
          conditions = []
          bind_values = {}

          # Personal: owned by user
          if user&.id
            conditions << "visibility = 'personal' AND owner_id = :user_id"
            bind_values[:user_id] = user.id
          end

          # Role: matching user's role(s)
          user_roles = resolve_user_roles(user)
          if user_roles.any?
            conditions << "visibility = 'role' AND target_role IN (:roles)"
            bind_values[:roles] = user_roles
          end

          # Group: matching user's group memberships
          user_groups = resolve_user_groups(user)
          if user_groups.any?
            conditions << "visibility = 'group' AND target_group IN (:groups)"
            bind_values[:groups] = user_groups
          end

          # Global: visible to everyone
          conditions << "visibility = 'global'"

          return [] if conditions.empty?

          combined = conditions.map { |c| "(#{c})" }.join(" OR ")
          scope = scope.where(combined, **bind_values)

          # Order: pinned first, then by position, then by name
          scope.order(pinned: :desc, position: :asc, name: :asc).to_a
        end

        # Returns the default filter for the given context, following priority:
        # personal > group > role > global
        #
        # @param presenter_slug [String]
        # @param user [Object]
        # @param evaluator [Authorization::PermissionEvaluator]
        # @return [ActiveRecord::Base, nil]
        def default_filter_for(presenter_slug:, user:, evaluator:)
          filters = visible_filters(presenter_slug: presenter_slug, user: user, evaluator: evaluator)
          defaults = filters.select { |f| f.respond_to?(:default_filter) && f.default_filter }
          return nil if defaults.empty?

          # Priority: personal > group > role > global
          priority_order = %w[personal group role global]
          priority_order.each do |vis|
            match = defaults.find { |f| f.visibility == vis }
            return match if match
          end

          defaults.first
        end

        # Clear any cached data (called from ChangeHandler after_commit)
        def clear_cache!
          # Currently no cache to clear — filters are loaded fresh each request.
          # This hook exists for future caching optimization.
        end

        private

        def resolve_user_roles(user)
          return [] unless user

          roles = user.send(LcpRuby.configuration.role_method)
          Array(roles).map(&:to_s)
        rescue NoMethodError
          []
        end

        def resolve_user_groups(user)
          return [] unless user
          return [] unless Groups::Registry.available?

          Groups::Registry.groups_for_user(user.id).map { |g| g.respond_to?(:name) ? g.name : g.to_s }
        rescue StandardError
          []
        end
      end
    end
  end
end
