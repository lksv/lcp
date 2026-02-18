require "spec_helper"
require "rake"

RSpec.describe "lcp_ruby:permissions rake task" do
  let(:fixtures_path) { File.expand_path("../../fixtures/metadata", __dir__) }

  before(:all) do
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    Rake.application.rake_require("lcp_ruby", [LcpRuby::Engine.root.join("lib", "tasks").to_s])
  end

  after(:all) do
    Rake::Task.clear
    Rake.application = Rake::Application.new
  end

  before do
    loader = LcpRuby::Metadata::Loader.new(fixtures_path)
    loader.load_all
    allow(LcpRuby).to receive(:loader).and_return(loader)
    allow(LcpRuby.configuration).to receive(:metadata_path).and_return(fixtures_path)
  end

  it "outputs permission matrix with model name and roles" do
    output = capture_stdout do
      Rake::Task["lcp_ruby:permissions"].reenable
      Rake::Task["lcp_ruby:permissions"].invoke
    end

    expect(output).to include("Permission Matrix")
    expect(output).to include("Model: project")
    expect(output).to include("admin")
    expect(output).to include("manager")
    expect(output).to include("viewer")
    expect(output).to include("Default role: viewer")
    expect(output).to include("Field overrides: budget")
    expect(output).to include("Record rules: 1")
  end

  it "outputs CRUD operations for each role" do
    output = capture_stdout do
      Rake::Task["lcp_ruby:permissions"].reenable
      Rake::Task["lcp_ruby:permissions"].invoke
    end

    expect(output).to include("index show create update destroy")
    expect(output).to include("index show")
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
