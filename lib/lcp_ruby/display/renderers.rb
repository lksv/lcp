# Require concerns first, then all built-in renderers
Dir[File.join(__dir__, "renderers", "concerns", "**", "*.rb")].sort.each { |f| require_relative f.delete_prefix("#{__dir__}/") }
Dir[File.join(__dir__, "renderers", "*.rb")].sort.each { |f| require_relative f.delete_prefix("#{__dir__}/") }
