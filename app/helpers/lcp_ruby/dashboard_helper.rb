module LcpRuby
  module DashboardHelper
    def format_kpi_value(value, format_type)
      return value.to_s if value.nil?

      case format_type&.to_s
      when "currency"
        number_with_delimiter(number_with_precision(value, precision: 2))
      when "percentage"
        "#{number_with_precision(value, precision: 1)}%"
      when "decimal"
        number_with_precision(value, precision: 2)
      when "integer"
        number_with_delimiter(value.to_i)
      else
        number_with_delimiter(value)
      end
    end

    def grid_style_for(zone)
      pos = zone.grid_position
      return "" if pos.empty?

      pos.map { |prop, val| "#{prop}: #{val}" }.join("; ")
    end

    def widget_partial_for(zone)
      if zone.widget?
        "lcp_ruby/widgets/#{zone.widget['type']}"
      else
        "lcp_ruby/widgets/presenter_zone"
      end
    end

    alias_method :zone_partial_for, :widget_partial_for

    def zone_renderable?(data)
      data.present? && !data[:hidden] && !data[:tab_only]
    end
  end
end
