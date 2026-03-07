require "spec_helper"

RSpec.describe LcpRuby::ArrayQuery do
  after do
    ActiveRecord::Base.connection.drop_table(:taggables) if ActiveRecord::Base.connection.table_exists?(:taggables)
  end

  def build_model(model_hash)
    model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(model_definition).build
  end

  let(:model_class) do
    build_model(
      "name" => "taggable",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "tags", "type" => "array", "item_type" => "string", "default" => [] },
        { "name" => "scores", "type" => "array", "item_type" => "integer", "default" => [] }
      ],
      "options" => { "timestamps" => false }
    )
  end

  before do
    model_class.create!(title: "a", tags: [ "ruby", "rails" ], scores: [ 1, 2 ])
    model_class.create!(title: "b", tags: [ "ruby", "python" ], scores: [ 3, 4 ])
    model_class.create!(title: "c", tags: [ "java" ], scores: [ 5 ])
    model_class.create!(title: "d", tags: [], scores: [])
  end

  describe ".contains" do
    it "finds records containing all given values" do
      result = described_class.contains(model_class.all, "taggables", "tags", [ "ruby", "rails" ])
      expect(result.pluck(:title)).to eq([ "a" ])
    end

    it "returns all when values are empty" do
      result = described_class.contains(model_class.all, "taggables", "tags", [])
      expect(result.count).to eq(4)
    end

    it "finds single value" do
      result = described_class.contains(model_class.all, "taggables", "tags", [ "ruby" ])
      expect(result.pluck(:title)).to contain_exactly("a", "b")
    end
  end

  describe ".overlaps" do
    it "finds records containing any given values" do
      result = described_class.overlaps(model_class.all, "taggables", "tags", [ "python", "java" ])
      expect(result.pluck(:title)).to contain_exactly("b", "c")
    end

    it "returns none when values are empty" do
      result = described_class.overlaps(model_class.all, "taggables", "tags", [])
      expect(result.count).to eq(0)
    end
  end

  describe ".contained_by" do
    it "finds records whose array is a subset" do
      result = described_class.contained_by(model_class.all, "taggables", "tags", [ "ruby", "rails", "python" ])
      titles = result.pluck(:title)
      expect(titles).to include("a", "b", "d")
      expect(titles).not_to include("c")
    end

    it "matches only empty arrays when values are empty" do
      result = described_class.contained_by(model_class.all, "taggables", "tags", [])
      expect(result.pluck(:title)).to eq([ "d" ])
    end
  end

  describe ".text_search_condition" do
    it "generates SQL for text search" do
      sql = described_class.text_search_condition("taggables", "tags", "rub")
      expect(sql).to be_a(String)
      expect(sql).to include("json_each")
    end

    it "works in a query" do
      sql = described_class.text_search_condition("taggables", "tags", "rub")
      result = model_class.where(Arel.sql(sql))
      expect(result.pluck(:title)).to contain_exactly("a", "b")
    end
  end

  describe ".array_length_expression" do
    it "generates SQL for array length" do
      expr = described_class.array_length_expression("taggables", "tags")
      result = model_class.select("title, (#{expr}) as tag_count").order(:title)
      counts = result.map { |r| [ r.title, r[:tag_count] ] }
      expect(counts).to include([ "a", 2 ], [ "c", 1 ], [ "d", 0 ])
    end
  end
end
