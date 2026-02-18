module LcpRuby
  module Display
    class BaseRenderer
      # @param value [Object] resolved field value
      # @param options [Hash] display_options from presenter config
      # @param record [ActiveRecord::Base, nil] full record (for context-aware renderers)
      # @param view_context [ActionView::Base, nil] for HTML helpers
      # @return [String] rendered output (HTML-safe)
      def render(value, options = {}, record: nil, view_context: nil)
        raise NotImplementedError
      end
    end
  end
end
