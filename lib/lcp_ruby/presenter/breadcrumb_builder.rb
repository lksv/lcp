module LcpRuby
  module Presenter
    class BreadcrumbBuilder
      Crumb = Struct.new(:label, :path, :current, keyword_init: true) do
        def initialize(label:, path: nil, current: false)
          super
        end

        alias_method :current?, :current
      end

      MAX_DEPTH = 5

      def initialize(view_group:, record:, action:, path_helper:)
        @view_group = view_group
        @record = record
        @action = action
        @path_helper = path_helper
      end

      def build
        return [] if @view_group && !@view_group.breadcrumb_enabled?

        crumbs = []
        crumbs << home_crumb

        if @record && @view_group&.breadcrumb_relation
          crumbs.concat(parent_crumbs(@view_group, @record, 0))
        end

        crumbs << current_list_crumb

        if @record&.persisted?
          crumbs << record_crumb
        end

        if %w[edit new].include?(@action)
          crumbs << action_crumb
        end

        crumbs.last.current = true if crumbs.any?
        crumbs
      end

      private

      def home_crumb
        Crumb.new(label: I18n.t("lcp_ruby.breadcrumbs.home", default: "Home"), path: LcpRuby.configuration.breadcrumb_home_path)
      end

      def current_list_crumb
        label = resolve_view_group_label(@view_group)
        slug = resolve_primary_slug(@view_group)
        Crumb.new(label: label, path: slug ? @path_helper.resources_path(slug) : nil)
      end

      def record_crumb
        label = record_label(@record)
        slug = resolve_primary_slug(@view_group)
        Crumb.new(label: label, path: slug ? @path_helper.resource_path(slug, @record.id) : nil)
      end

      def action_crumb
        Crumb.new(label: I18n.t("lcp_ruby.breadcrumbs.#{@action}", default: @action.humanize))
      end

      def parent_crumbs(view_group, record, depth)
        return [] if depth >= MAX_DEPTH

        relation_name = view_group.breadcrumb_relation
        return [] unless relation_name

        model_def = LcpRuby.loader.model_definition(view_group.model)
        assoc = model_def.associations.find { |a| a.name == relation_name }
        return [] unless assoc

        preload_association(record, relation_name)

        parent_record = record.respond_to?(relation_name) ? record.send(relation_name) : nil
        return [] unless parent_record

        target_model = resolve_target_model(assoc, record)
        return [] unless target_model

        parent_vg = LcpRuby.loader.view_groups_for_model(target_model).first
        return [] unless parent_vg

        crumbs = []

        if parent_vg.breadcrumb_relation
          crumbs.concat(parent_crumbs(parent_vg, parent_record, depth + 1))
        end

        parent_label = resolve_view_group_label(parent_vg)
        parent_slug = resolve_primary_slug(parent_vg)
        if parent_slug
          crumbs << Crumb.new(label: parent_label, path: @path_helper.resources_path(parent_slug))
        end

        crumbs << Crumb.new(
          label: record_label(parent_record),
          path: parent_slug ? @path_helper.resource_path(parent_slug, parent_record.id) : nil
        )

        crumbs
      end

      def preload_association(record, association_name)
        return unless record.persisted? && record.respond_to?(:association)

        ActiveRecord::Associations::Preloader.new(
          records: [ record ],
          associations: [ association_name.to_sym ]
        ).call
      end

      def resolve_target_model(assoc, record)
        if assoc.polymorphic
          type_value = record.respond_to?("#{assoc.name}_type") ? record.send("#{assoc.name}_type") : nil
          return nil unless type_value
          type_value.demodulize.underscore
        else
          assoc.target_model
        end
      end

      def resolve_view_group_label(view_group)
        return "Unknown" unless view_group
        presenter = LcpRuby.loader.presenter_definitions[view_group.primary_presenter]
        presenter&.label || view_group.name.humanize
      end

      def resolve_primary_slug(view_group)
        return nil unless view_group
        presenter = LcpRuby.loader.presenter_definitions[view_group.primary_presenter]
        presenter&.slug
      end

      def record_label(record)
        if record.respond_to?(:to_label)
          record.to_label.to_s
        else
          record.to_s
        end
      end
    end
  end
end
