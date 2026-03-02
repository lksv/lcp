module LcpRuby
  module ViewSlots
    class SlotComponent
      attr_reader :page, :slot, :name, :partial, :position, :enabled_callback

      def initialize(page:, slot:, name:, partial:, position: 10, enabled: nil)
        @page = page.to_sym
        @slot = slot.to_sym
        @name = name.to_sym
        @partial = partial
        @position = position
        @enabled_callback = enabled
      end

      def enabled?(context)
        return true unless enabled_callback

        enabled_callback.call(context)
      end
    end
  end
end
