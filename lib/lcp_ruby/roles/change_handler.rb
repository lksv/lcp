module LcpRuby
  module Roles
    class ChangeHandler
      def self.install!(model_class)
        model_class.after_commit do |_record|
          Registry.reload!
        end
      end
    end
  end
end
