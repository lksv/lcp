module LcpRuby
  module HostActions
    module ShowcasePermission
      class Lock < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No record specified")
          end

          if record.status == "locked"
            return failure(message: "Record is already locked")
          end

          record.update!(status: "locked")
          success(message: "Record '#{record.title}' has been locked.")
        end
      end
    end
  end
end
