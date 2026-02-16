module LcpRuby
  module Dsl
    class DslLoader
      def self.load_types(dir)
        definitions = {}
        return definitions unless dir.exist?

        Dir[dir.join("*.rb")].sort.each do |file_path|
          context = TypeEvalContext.new
          context.instance_eval(File.read(file_path), file_path)
          context.type_definitions.each do |type_def|
            if definitions.key?(type_def.name)
              raise MetadataError,
                "Duplicate type '#{type_def.name}' in DSL files — conflict at #{file_path}"
            end
            definitions[type_def.name] = type_def
          end
        rescue SyntaxError => e
          raise MetadataError, "Ruby DSL syntax error in #{file_path}: #{e.message}"
        end

        definitions
      end

      def self.load_models(dir)
        definitions = {}
        return definitions unless dir.exist?

        Dir[dir.join("*.rb")].sort.each do |file_path|
          dsl_definitions = load_file(file_path)
          dsl_definitions.each do |definition|
            if definitions.key?(definition.name)
              raise MetadataError,
                "Duplicate model '#{definition.name}' in DSL files — conflict at #{file_path}"
            end
            definitions[definition.name] = definition
          end
        end

        definitions
      end

      def self.load_presenters(dir)
        definitions = {}
        return definitions unless dir.exist?

        # Pass 1: Evaluate all files, collect (name, inherits, builder) tuples
        entries = []
        Dir[dir.join("*.rb")].sort.each do |file_path|
          context = PresenterEvalContext.new
          context.instance_eval(File.read(file_path), file_path)
          context.entries.each do |entry|
            entry[:source_path] = file_path
            entries << entry
          end
        rescue SyntaxError => e
          raise MetadataError, "Ruby DSL syntax error in #{file_path}: #{e.message}"
        end

        # Check for duplicates within DSL files
        seen = {}
        entries.each do |entry|
          name = entry[:name]
          if seen.key?(name)
            raise MetadataError,
              "Duplicate presenter '#{name}' in DSL files — conflict at #{entry[:source_path]}"
          end
          seen[name] = entry
        end

        # Pass 2: Resolve inheritance via topological sort
        resolved = resolve_presenter_inheritance(entries, seen)
        resolved.each do |definition|
          definitions[definition.name] = definition
        end

        definitions
      end

      def self.load_file(file_path)
        context = EvalContext.new
        context.instance_eval(File.read(file_path), file_path)
        context.definitions
      rescue SyntaxError => e
        raise MetadataError, "Ruby DSL syntax error in #{file_path}: #{e.message}"
      end

      def self.resolve_presenter_inheritance(entries, entries_by_name)
        # Build adjacency: child -> parent
        order = topological_sort_presenters(entries, entries_by_name)

        resolved_hashes = {}
        definitions = []

        order.each do |entry|
          name = entry[:name]
          builder = entry[:builder]
          inherits = entry[:inherits]

          hash = if inherits
                   parent_hash = resolved_hashes[inherits]
                   unless parent_hash
                     raise MetadataError,
                       "Presenter '#{name}' inherits from '#{inherits}', but '#{inherits}' was not found"
                   end
                   builder.to_hash_with_parent(parent_hash)
          else
                   builder.to_hash
          end

          resolved_hashes[name] = hash
          definitions << Metadata::PresenterDefinition.from_hash(hash)
        end

        definitions
      end
      private_class_method :resolve_presenter_inheritance

      def self.topological_sort_presenters(entries, entries_by_name)
        # Simple topological sort: parents before children
        sorted = []
        visited = {}
        visiting = {}

        visit = lambda do |entry|
          name = entry[:name]
          return if visited[name]

          if visiting[name]
            raise MetadataError, "Circular inheritance detected for presenter '#{name}'"
          end

          visiting[name] = true

          if entry[:inherits]
            parent = entries_by_name[entry[:inherits]]
            # If parent not found in DSL entries, resolution will raise a clear error.
            # Cross-format inheritance (DSL child from YAML parent) is not supported.
            visit.call(parent) if parent
          end

          visiting.delete(name)
          visited[name] = true
          sorted << entry
        end

        entries.each { |entry| visit.call(entry) }
        sorted
      end
      private_class_method :topological_sort_presenters

      # Isolated evaluation context to prevent DSL files from
      # accessing the DslLoader internals.
      class EvalContext
        attr_reader :definitions

        def initialize
          @definitions = []
        end

        def define_model(name, &block)
          builder = ModelBuilder.new(name)
          builder.instance_eval(&block)
          hash = builder.to_hash
          @definitions << Metadata::ModelDefinition.from_hash(hash)
        end
      end

      # Isolated evaluation context for type DSL files.
      class TypeEvalContext
        attr_reader :type_definitions

        def initialize
          @type_definitions = []
        end

        def define_type(name, &block)
          builder = TypeBuilder.new(name)
          builder.instance_eval(&block)
          hash = builder.to_hash
          @type_definitions << Types::TypeDefinition.from_hash(hash)
        end
      end

      # Isolated evaluation context for presenter DSL files.
      class PresenterEvalContext
        attr_reader :entries

        def initialize
          @entries = []
        end

        def define_presenter(name, inherits: nil, &block)
          builder = PresenterBuilder.new(name)
          builder.instance_eval(&block)
          @entries << { name: name.to_s, inherits: inherits&.to_s, builder: builder }
        end
      end
    end
  end
end
