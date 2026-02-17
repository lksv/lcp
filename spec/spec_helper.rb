ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"

require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:each) do
    LcpRuby.reset!
    LcpRuby::Events::HandlerRegistry.clear!
    LcpRuby::Actions::ActionRegistry.clear!
    LcpRuby::Authorization::PolicyFactory.clear!
    LcpRuby::Types::TypeRegistry.clear!
    LcpRuby::Types::ServiceRegistry.clear!
    LcpRuby::ConditionServiceRegistry.clear!

    # Remove dynamic constants
    LcpRuby::Dynamic.constants.each do |const|
      LcpRuby::Dynamic.send(:remove_const, const)
    end
  end
end
