module LcpRuby
  module HostActions
    module Asset
      class AssignAsset < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No asset specified")
          end

          unless record.status == "available"
            return failure(message: "Only available assets can be assigned (current status: #{record.status})")
          end

          record.update!(status: "assigned")
          success(message: "Asset '#{record.name}' (#{record.asset_tag}) marked as assigned")
        end
      end
    end
  end
end
