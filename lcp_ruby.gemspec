require_relative "lib/lcp_ruby/version"

Gem::Specification.new do |spec|
  spec.name        = "lcp_ruby"
  spec.version     = LcpRuby::VERSION
  spec.authors     = [ "LCP Ruby Contributors" ]
  spec.email       = [ "lcp-ruby@example.com" ]
  spec.homepage    = "https://github.com/lksv/lcp-ruby"
  spec.summary     = "Low Code Platform engine for Rails"
  spec.description = "Rails mountable engine that creates information systems from YAML metadata"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib,vendor}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "rails", ">= 7.1", "< 9.0"
  spec.add_dependency "pundit", "~> 2.3"
  spec.add_dependency "ransack", "~> 4.0"
  spec.add_dependency "kaminari", "~> 1.2"
  spec.add_dependency "view_component", "~> 3.0"
  spec.add_dependency "turbo-rails", "~> 2.0"
  spec.add_dependency "stimulus-rails", "~> 1.3"
  spec.add_dependency "commonmarker", "~> 2.0"
end
