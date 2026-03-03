module LcpRuby
  module HostEventHandlers
    module AssetAssignment
      class OnCreate < LcpRuby::Events::HandlerBase
        def self.handles_event
          "after_create"
        end

        def call
          asset_model = LcpRuby.registry.model_for("asset")
          asset = asset_model.find_by(id: record.asset_id)

          unless asset
            Rails.logger.warn("[HR] Asset ##{record.asset_id} not found for assignment ##{record.id}")
            return
          end

          asset.update!(status: "assigned")
          Rails.logger.info("[HR] Asset '#{asset.name}' (#{asset.asset_tag}) assigned to employee ##{record.employee_id}")
        end
      end
    end
  end
end
