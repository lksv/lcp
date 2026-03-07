module LcpRuby
  module Dsl
    class ViewGroupBuilder
      def initialize(name)
        @name = name.to_s
        @model_name = nil
        @primary_value = nil
        @navigation_hash = nil
        @breadcrumb_value = nil
        @switcher_value = nil
        @views = []
      end

      def model(value)
        @model_name = value.to_s
      end

      def primary(value)
        @primary_value = value.to_s
      end

      def navigation(value = nil, menu: nil, position: nil)
        if value == false
          @navigation_hash = false
        elsif menu
          @navigation_hash = { "menu" => menu.to_s }
          @navigation_hash["position"] = position if position
        else
          raise ArgumentError, "navigation expects `false` or `menu:` keyword, got: #{value.inspect}"
        end
      end

      def breadcrumb(value = nil, relation: nil)
        if value == false
          @breadcrumb_value = false
        elsif relation
          @breadcrumb_value = { "relation" => relation.to_s }
        elsif !value.nil?
          raise ArgumentError, "breadcrumb expects `false` or `relation:` keyword, got: #{value.inspect}"
        end
      end

      def switcher(*args)
        if args.length == 1 && args.first == false
          @switcher_value = false
        elsif args.length == 1 && args.first == :auto
          @switcher_value = "auto"
        elsif args.length == 1 && args.first.is_a?(Array)
          @switcher_value = args.first.map(&:to_s)
        else
          @switcher_value = args.map(&:to_s)
        end
      end

      def view(page_name, label: nil, icon: nil)
        view_hash = { "page" => page_name.to_s }
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
        vg["navigation"] = @navigation_hash unless @navigation_hash.nil?
        vg["breadcrumb"] = @breadcrumb_value unless @breadcrumb_value.nil?
        vg["switcher"] = @switcher_value unless @switcher_value.nil?
        vg["views"] = @views unless @views.empty?
        hash
      end
    end
  end
end
