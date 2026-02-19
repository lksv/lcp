module LcpRuby
  module HostActions
    module FeatureRecord
      class Lock < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No record specified")
          end

          if record.status == "locked"
            return failure(message: "Record is already locked")
          end

          record.update!(status: "locked")
          success(message: "Record '#{record.name}' has been locked.")
        end
      end
    end
  end
end
