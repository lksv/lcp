module LcpRuby
  module Groups
    class ChangeHandler
      # Installs after_commit callbacks on group-related models to invalidate caches.
      # @param group_class [Class] the group AR model
      # @param membership_class [Class] the group membership AR model
      # @param mapping_class [Class, nil] the group role mapping AR model (optional)
      def self.install!(group_class, membership_class, mapping_class = nil)
        [ group_class, membership_class, mapping_class ].compact.each do |model_class|
          model_class.after_commit do |_record|
            Registry.reload!
            Authorization::PolicyFactory.clear!
          end
        end
      end
    end
  end
end
