module LcpRuby
  module Dsl
    class DslLoader
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

      def self.load_file(file_path)
        context = EvalContext.new
        context.instance_eval(File.read(file_path), file_path)
        context.definitions
      rescue SyntaxError => e
        raise MetadataError, "Ruby DSL syntax error in #{file_path}: #{e.message}"
      end

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
    end
  end
end
