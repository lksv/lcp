module LcpRuby
  module Metadata
    # Generates Entity-Relationship Diagrams from loaded model definitions.
    #
    # Supported output formats:
    #   - :mermaid  — Mermaid.js syntax (renders in GitHub markdown, Mermaid Live Editor)
    #   - :dot      — Graphviz DOT language (export to PNG/SVG via `dot -Tpng`)
    #   - :plantuml — PlantUML syntax (renders via PlantUML server or CLI)
    #
    # Usage:
    #   generator = ErdGenerator.new(loader)
    #   puts generator.generate(:mermaid)
    #   File.write("erd.dot", generator.generate(:dot))
    class ErdGenerator
      SUPPORTED_FORMATS = %i[mermaid dot plantuml].freeze

      attr_reader :loader

      def initialize(loader)
        @loader = loader
      end

      def generate(format = :mermaid)
        format = format.to_sym
        unless SUPPORTED_FORMATS.include?(format)
          raise ArgumentError,
            "Unsupported format '#{format}'. Supported: #{SUPPORTED_FORMATS.join(', ')}"
        end

        send(:"generate_#{format}")
      end

      private

      def models
        @models ||= loader.model_definitions.values
      end

      def model_names
        @model_names ||= loader.model_definitions.keys
      end

      # --- Mermaid ---

      def generate_mermaid
        lines = [ "erDiagram" ]

        models.each do |model|
          lines << mermaid_entity(model)
        end

        lines << ""

        models.each do |model|
          model.associations.each do |assoc|
            line = mermaid_relationship(model, assoc)
            lines << line if line
          end
        end

        lines.join("\n")
      end

      def mermaid_entity(model)
        lines = [ "  #{mermaid_name(model.name)} {" ]

        model.fields.each do |field|
          pk = ""
          constraint = required_field?(field) ? " \"NOT NULL\"" : ""
          lines << "    #{mermaid_type(field.type)} #{field.name}#{constraint}#{pk}"
        end

        if model.timestamps?
          lines << "    datetime created_at"
          lines << "    datetime updated_at"
        end

        # Add FK fields from belongs_to associations
        model.associations.select { |a| a.type == "belongs_to" }.each do |assoc|
          fk = assoc.foreign_key || "#{assoc.name}_id"
          lines << "    integer #{fk} FK"
        end

        lines << "  }"
        lines.join("\n")
      end

      def mermaid_relationship(model, assoc)
        return nil unless assoc.lcp_model? && model_names.include?(assoc.target_model)

        # Only render from belongs_to side to avoid duplicates
        return nil unless assoc.type == "belongs_to"

        left = mermaid_name(model.name)
        right = mermaid_name(assoc.target_model)
        cardinality = assoc.required ? "}|--||" : "}o--||"

        "  #{left} #{cardinality} #{right} : \"#{assoc.name}\""
      end

      def mermaid_name(name)
        name.to_s.camelize
      end

      def mermaid_type(type)
        case type
        when "string", "text", "uuid" then "string"
        when "integer" then "int"
        when "float", "decimal" then "float"
        when "boolean" then "bool"
        when "date" then "date"
        when "datetime" then "datetime"
        when "enum" then "string"
        when "json" then "jsonb"
        when "file" then "string"
        when "rich_text" then "text"
        else type
        end
      end

      # --- DOT/Graphviz ---

      def generate_dot
        lines = [
          "digraph ERD {",
          '  graph [rankdir=LR, fontname="Helvetica", fontsize=12];',
          '  node [shape=record, fontname="Helvetica", fontsize=10];',
          '  edge [fontname="Helvetica", fontsize=9];',
          ""
        ]

        models.each do |model|
          lines << dot_entity(model)
        end

        lines << ""

        models.each do |model|
          model.associations.each do |assoc|
            line = dot_relationship(model, assoc)
            lines << line if line
          end
        end

        lines << "}"
        lines.join("\n")
      end

      def dot_entity(model)
        fields_str = model.fields.map do |f|
          null_marker = required_field?(f) ? " NOT NULL" : ""
          "#{f.name} : #{f.type}#{null_marker}"
        end

        if model.timestamps?
          fields_str << "created_at : datetime"
          fields_str << "updated_at : datetime"
        end

        model.associations.select { |a| a.type == "belongs_to" }.each do |assoc|
          fk = assoc.foreign_key || "#{assoc.name}_id"
          fields_str << "#{fk} : integer FK"
        end

        label = "{#{model.name}|#{fields_str.join('\\l')}\\l}"
        "  #{dot_name(model.name)} [label=\"#{label}\"];"
      end

      def dot_relationship(model, assoc)
        return nil unless assoc.lcp_model? && model_names.include?(assoc.target_model)
        return nil unless assoc.type == "belongs_to"

        from = dot_name(model.name)
        to = dot_name(assoc.target_model)
        style = assoc.required ? "solid" : "dashed"

        "  #{from} -> #{to} [label=\"#{assoc.name}\", style=#{style}];"
      end

      def dot_name(name)
        name.to_s.underscore
      end

      # --- PlantUML ---

      def generate_plantuml
        lines = [
          "@startuml",
          "skinparam linetype ortho",
          ""
        ]

        models.each do |model|
          lines << plantuml_entity(model)
          lines << ""
        end

        models.each do |model|
          model.associations.each do |assoc|
            line = plantuml_relationship(model, assoc)
            lines << line if line
          end
        end

        lines << ""
        lines << "@enduml"
        lines.join("\n")
      end

      def plantuml_entity(model)
        lines = [ "entity \"#{model.label || model.name}\" as #{plantuml_name(model.name)} {" ]

        # PK
        lines << "  * id : integer <<PK>>"
        lines << "  --"

        model.fields.each do |f|
          marker = required_field?(f) ? "* " : "  "
          lines << "  #{marker}#{f.name} : #{f.type}"
        end

        model.associations.select { |a| a.type == "belongs_to" }.each do |assoc|
          fk = assoc.foreign_key || "#{assoc.name}_id"
          marker = assoc.required ? "* " : "  "
          lines << "  #{marker}#{fk} : integer <<FK>>"
        end

        if model.timestamps?
          lines << "  --"
          lines << "  created_at : datetime"
          lines << "  updated_at : datetime"
        end

        lines << "}"
        lines.join("\n")
      end

      def plantuml_relationship(model, assoc)
        return nil unless assoc.lcp_model? && model_names.include?(assoc.target_model)
        return nil unless assoc.type == "belongs_to"

        from = plantuml_name(model.name)
        to = plantuml_name(assoc.target_model)
        cardinality = assoc.required ? "}|--||" : "}o--||"

        "#{from} #{cardinality} #{to} : #{assoc.name}"
      end

      def plantuml_name(name)
        name.to_s.underscore
      end

      # --- Helpers ---

      def required_field?(field)
        field.validations.any? { |v| v.type == "presence" } ||
          field.column_options[:null] == false
      end
    end
  end
end
