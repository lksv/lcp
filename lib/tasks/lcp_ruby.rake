namespace :lcp_ruby do
  desc "Validate LCP Ruby YAML configuration (models, presenters, permissions)"
  task validate: :environment do
    require "lcp_ruby"

    path = LcpRuby.configuration.metadata_path
    puts "Validating configuration at: #{path}"
    puts ""

    begin
      loader = LcpRuby::Metadata::Loader.new(path)
      loader.load_all
    rescue LcpRuby::MetadataError => e
      puts "[FATAL] Failed to load metadata: #{e.message}"
      exit 1
    end

    validator = LcpRuby::Metadata::ConfigurationValidator.new(loader)
    result = validator.validate

    puts result
    puts ""
    puts "Models:      #{loader.model_definitions.size}"
    puts "Presenters:  #{loader.presenter_definitions.size}"
    puts "Permissions: #{loader.permission_definitions.size}"

    exit 1 unless result.valid?
  end

  desc "Generate ERD diagram from LCP Ruby models (FORMAT=mermaid|dot|plantuml, OUTPUT=file)"
  task erd: :environment do
    require "lcp_ruby"

    format = (ENV["FORMAT"] || "mermaid").to_sym
    output = ENV["OUTPUT"]

    path = LcpRuby.configuration.metadata_path
    puts "Generating ERD from: #{path}"
    puts "Format: #{format}"

    begin
      loader = LcpRuby::Metadata::Loader.new(path)
      loader.load_all
    rescue LcpRuby::MetadataError => e
      puts "[FATAL] Failed to load metadata: #{e.message}"
      exit 1
    end

    generator = LcpRuby::Metadata::ErdGenerator.new(loader)

    begin
      diagram = generator.generate(format)
    rescue ArgumentError => e
      puts "[ERROR] #{e.message}"
      exit 1
    end

    if output
      File.write(output, diagram)
      puts "ERD written to: #{output}"

      extension_hint = case format
      when :mermaid then ".md (wrap in ```mermaid ... ``` block)"
      when :dot then ".dot (render with: dot -Tpng #{output} -o erd.png)"
      when :plantuml then ".puml (render with: plantuml #{output})"
      end
      puts "Hint: #{extension_hint}" if extension_hint
    else
      puts ""
      puts diagram
    end
  end
end
