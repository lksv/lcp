module LcpRuby
  module LayoutHelper
    def hidden_on_classes(config)
      return "" unless config.is_a?(Hash)
      classes = []
      hidden_on = config["hidden_on"]
      if hidden_on.is_a?(Array)
        hidden_on.each do |breakpoint|
          classes << "lcp-hidden-#{breakpoint}"
        end
      elsif hidden_on.is_a?(String)
        classes << "lcp-hidden-#{hidden_on}"
      end
      classes.join(" ")
    end
  end
end
