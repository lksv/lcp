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

    # Check service references
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Services::Registry.discover!(Rails.root.join("app").to_s)

    service_result = LcpRuby::Services::Checker.new(loader.model_definitions).check
    puts service_result
    puts ""

    puts "Models:      #{loader.model_definitions.size}"
    puts "Presenters:  #{loader.presenter_definitions.size}"
    puts "Permissions: #{loader.permission_definitions.size}"

    exit 1 unless result.valid? && service_result.valid?
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

  desc "Display permission matrix for all models and roles"
  task permissions: :environment do
    require "lcp_ruby"

    path = LcpRuby.configuration.metadata_path

    begin
      loader = LcpRuby::Metadata::Loader.new(path)
      loader.load_all
    rescue LcpRuby::MetadataError => e
      puts "[FATAL] Failed to load metadata: #{e.message}"
      exit 1
    end

    puts "Permission Matrix"
    puts "================="
    puts ""

    loader.permission_definitions.each do |model_name, perm_def|
      puts "Model: #{model_name}"

      roles = perm_def.roles
      if roles.empty?
        puts "  (no roles defined)"
        puts ""
        next
      end

      # Header
      header = format("  %-14s | %-35s | %-13s | %-13s | %-11s | %s",
        "Role", "CRUD", "Fields (R/W)", "Actions", "Scope", "Presenters")
      puts header
      puts "  #{'-' * 14}-|-#{'-' * 35}-|-#{'-' * 13}-|-#{'-' * 13}-|-#{'-' * 11}-|-#{'-' * 18}"

      roles.each do |role_name, config|
        crud = Array(config["crud"]).join(" ")

        readable = config.dig("fields", "readable")
        writable = config.dig("fields", "writable")
        r_count = readable == "all" ? "all" : Array(readable).size.to_s
        w_count = writable == "all" ? "all" : Array(writable).size.to_s
        fields = "#{r_count} / #{w_count}"

        actions = config["actions"]
        actions_str = if actions == "all"
          "all"
        elsif actions.is_a?(Hash)
          allowed = actions["allowed"]
          if allowed == "all"
            "all"
          elsif Array(allowed).empty?
            "none"
          else
            Array(allowed).join(", ")
          end
        else
          "none"
        end

        scope = config["scope"]
        scope_str = if scope == "all"
          "all"
        elsif scope.is_a?(Hash)
          scope["type"] || "custom"
        else
          "all"
        end

        presenters = config["presenters"]
        presenters_str = if presenters == "all"
          "all"
        elsif presenters.is_a?(Array)
          presenters.join(", ")
        else
          "all"
        end

        puts format("  %-14s | %-35s | %-13s | %-13s | %-11s | %s",
          role_name, crud, fields, actions_str, scope_str, presenters_str)
      end

      puts "  Default role: #{perm_def.default_role}"

      if perm_def.field_overrides.any?
        puts "  Field overrides: #{perm_def.field_overrides.keys.join(', ')}"
      end

      if perm_def.record_rules.any?
        puts "  Record rules: #{perm_def.record_rules.size}"
      end

      puts ""
    end
  end
end
