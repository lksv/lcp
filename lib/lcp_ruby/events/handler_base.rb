module LcpRuby
  module Events
    class HandlerBase
      attr_reader :record, :changes, :current_user, :event_name

      def initialize(context = {})
        @record = context[:record]
        @changes = context[:changes] || {}
        @current_user = context[:current_user]
        @event_name = context[:event_name]
      end

      def call
        raise NotImplementedError, "#{self.class}#call must be implemented"
      end

      def self.handles_event
        raise NotImplementedError, "#{name}.handles_event must be implemented"
      end

      def self.async?
        false
      end

      protected

      def old_value(field)
        changes.dig(field.to_s, 0)
      end

      def new_value(field)
        changes.dig(field.to_s, 1)
      end

      def field_changed?(field)
        changes.key?(field.to_s)
      end
    end
  end
end
