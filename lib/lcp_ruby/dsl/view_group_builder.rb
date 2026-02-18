module LcpRuby
  module Dsl
    class ViewGroupBuilder
      def initialize(name)
        @name = name.to_s
        @model_name = nil
        @primary_value = nil
        @navigation_hash = nil
        @views = []
      end

      def model(value)
        @model_name = value.to_s
      end

      def primary(value)
        @primary_value = value.to_s
      end

      def navigation(menu:, position: nil)
        @navigation_hash = { "menu" => menu.to_s }
        @navigation_hash["position"] = position if position
      end

      def view(presenter_name, label: nil, icon: nil)
        view_hash = { "presenter" => presenter_name.to_s }
        view_hash["label"] = label if label
        view_hash["icon"] = icon.to_s if icon
        @views << view_hash
      end

      def to_hash
        hash = {
          "view_group" => {
            "name" => @name
          }
        }
        vg = hash["view_group"]
        vg["model"] = @model_name if @model_name
        vg["primary"] = @primary_value if @primary_value
        vg["navigation"] = @navigation_hash if @navigation_hash
        vg["views"] = @views unless @views.empty?
        hash
      end
    end
  end
end
