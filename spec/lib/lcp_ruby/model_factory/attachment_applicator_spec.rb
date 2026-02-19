require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::AttachmentApplicator do
  let(:model_hash) do
    {
      "name" => "upload_test",
      "fields" => [
        { "name" => "title", "type" => "string" },
        {
          "name" => "photo",
          "type" => "attachment",
          "label" => "Photo",
          "options" => {
            "accept" => "image/*",
            "max_size" => "5MB",
            "content_types" => %w[image/jpeg image/png],
            "variants" => {
              "thumbnail" => { "resize_to_limit" => [ 100, 100 ] },
              "medium" => { "resize_to_limit" => [ 300, 300 ] }
            }
          }
        },
        {
          "name" => "documents",
          "type" => "attachment",
          "label" => "Documents",
          "options" => {
            "multiple" => true,
            "max_files" => 3,
            "max_size" => "10MB",
            "content_types" => %w[application/pdf image/*]
          }
        }
      ],
      "options" => { "timestamps" => false }
    }
  end

  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash) }

  before do
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:upload_tests) if ActiveRecord::Base.connection.table_exists?(:upload_tests)
  end

  describe "#apply!" do
    subject(:model_class) { LcpRuby::ModelFactory::Builder.new(model_definition).build }

    it "applies has_one_attached for single attachment" do
      reflection = model_class.reflect_on_attachment(:photo)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_one_attached)
    end

    it "applies has_many_attached for multiple attachment" do
      reflection = model_class.reflect_on_attachment(:documents)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many_attached)
    end

    it "stores variant config as class attribute" do
      expect(model_class).to respond_to(:lcp_attachment_variants)
      variants = model_class.lcp_attachment_variants
      expect(variants["photo"]).to be_a(Hash)
      expect(variants["photo"]["thumbnail"]).to eq({ "resize_to_limit" => [ 100, 100 ] })
      expect(variants["photo"]["medium"]).to eq({ "resize_to_limit" => [ 300, 300 ] })
    end

    it "does not create a database column for attachment fields" do
      columns = ActiveRecord::Base.connection.columns(:upload_tests).map(&:name)
      expect(columns).to include("title")
      expect(columns).not_to include("photo")
      expect(columns).not_to include("documents")
    end
  end

  describe "size validation" do
    subject(:model_class) { LcpRuby::ModelFactory::Builder.new(model_definition).build }

    it "rejects files exceeding max_size" do
      record = model_class.new(title: "Test")
      # Create an oversized blob (6MB > 5MB limit)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("x" * (6 * 1024 * 1024)),
        filename: "large.jpg",
        content_type: "image/jpeg"
      )
      record.photo.attach(blob)

      expect(record).not_to be_valid
      expect(record.errors[:photo].join).to include("too large")
    end

    it "accepts files within max_size" do
      record = model_class.new(title: "Test")
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("x" * 1024),
        filename: "small.jpg",
        content_type: "image/jpeg"
      )
      record.photo.attach(blob)

      record.valid?
      expect(record.errors[:photo]).to be_empty
    end
  end

  describe "content_type validation" do
    subject(:model_class) { LcpRuby::ModelFactory::Builder.new(model_definition).build }

    it "rejects files with disallowed content type" do
      record = model_class.new(title: "Test")
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("test"),
        filename: "test.txt",
        content_type: "text/plain"
      )
      record.photo.attach(blob)

      expect(record).not_to be_valid
      expect(record.errors[:photo].join).to include("invalid content type")
    end

    it "accepts files with allowed content type" do
      record = model_class.new(title: "Test")
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("x" * 100),
        filename: "test.png",
        content_type: "image/png"
      )
      record.photo.attach(blob)

      record.valid?
      expect(record.errors[:photo]).to be_empty
    end
  end

  describe "max_files validation (multiple)" do
    subject(:model_class) { LcpRuby::ModelFactory::Builder.new(model_definition).build }

    it "rejects when exceeding max_files" do
      record = model_class.new(title: "Test")
      4.times do |i|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("file#{i}"),
          filename: "file#{i}.pdf",
          content_type: "application/pdf"
        )
        record.documents.attach(blob)
      end

      expect(record).not_to be_valid
      expect(record.errors[:documents].join).to include("too many files")
    end

    it "accepts within max_files limit" do
      record = model_class.new(title: "Test")
      2.times do |i|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("file#{i}"),
          filename: "file#{i}.pdf",
          content_type: "application/pdf"
        )
        record.documents.attach(blob)
      end

      record.valid?
      expect(record.errors[:documents]).to be_empty
    end
  end

  describe "wildcard content_type matching (multiple)" do
    subject(:model_class) { LcpRuby::ModelFactory::Builder.new(model_definition).build }

    it "accepts image/* wildcard match for multiple attachment" do
      record = model_class.new(title: "Test")
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("x" * 100),
        filename: "test.webp",
        content_type: "image/webp"
      )
      record.documents.attach(blob)

      record.valid?
      expect(record.errors[:documents]).to be_empty
    end
  end

  describe "parse_size" do
    subject(:applicator) do
      described_class.new(Class.new(ActiveRecord::Base), model_definition)
    end

    it "parses MB correctly" do
      expect(applicator.send(:parse_size, "10MB")).to eq(10 * 1024 * 1024)
    end

    it "parses KB correctly" do
      expect(applicator.send(:parse_size, "512KB")).to eq(512 * 1024)
    end

    it "parses GB correctly" do
      expect(applicator.send(:parse_size, "1GB")).to eq(1024 * 1024 * 1024)
    end

    it "parses B correctly" do
      expect(applicator.send(:parse_size, "100B")).to eq(100)
    end

    it "returns nil for invalid format" do
      expect(applicator.send(:parse_size, "invalid")).to be_nil
    end

    it "returns nil for non-string" do
      expect(applicator.send(:parse_size, nil)).to be_nil
    end
  end
end
