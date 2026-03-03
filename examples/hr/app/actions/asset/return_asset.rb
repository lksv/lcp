module LcpRuby
  module HostActions
    module Asset
      class ReturnAsset < LcpRuby::Actions::BaseAction
        def call
          unless record
            return failure(message: "No asset specified")
          end

          unless record.status == "assigned"
            return failure(message: "Only assigned assets can be returned (current status: #{record.status})")
          end

          record.update!(status: "available")
          success(message: "Asset '#{record.name}' (#{record.asset_tag}) returned and available")
        end
      end
    end
  end
end
