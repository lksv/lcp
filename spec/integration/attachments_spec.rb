require "spec_helper"
require "support/integration_helper"

RSpec.describe "File Attachments", type: :request do
  before(:each) do
    load_integration_metadata!("attachments")
    stub_current_user(role: "admin")
    Rails.application.config.action_dispatch.show_exceptions = :none
  end

  after(:each) do
    Rails.application.config.action_dispatch.show_exceptions = :all
    teardown_integration_tables!("attachments")
  end

  let(:model_class) { LcpRuby.registry.model_for("document") }

  describe "creating a record with a single attachment" do
    it "attaches a file on create" do
      file = create_upload("image data", "test.jpg", "image/jpeg")

      post lcp_ruby.resources_path(lcp_slug: "documents"), params: {
        record: { title: "My Document", photo: file }
      }

      expect(response).to have_http_status(:redirect)
      record = model_class.last
      expect(record.title).to eq("My Document")
      expect(record.photo).to be_attached
    end
  end

  describe "creating a record with multiple attachments" do
    it "attaches multiple files on create" do
      file1 = create_upload("pdf data", "doc1.pdf", "application/pdf")
      file2 = create_upload("pdf data 2", "doc2.pdf", "application/pdf")

      post lcp_ruby.resources_path(lcp_slug: "documents"), params: {
        record: { title: "Multi Doc", files: [ file1, file2 ] }
      }

      expect(response).to have_http_status(:redirect)
      record = model_class.last
      expect(record.files).to be_attached
      expect(record.files.count).to eq(2)
    end
  end

  describe "showing a record with attachments" do
    it "renders the show page" do
      record = model_class.create!(title: "Show Test")

      get lcp_ruby.resource_path(lcp_slug: "documents", id: record.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Show Test")
    end
  end

  describe "editing a record with attachments" do
    it "renders the edit page" do
      record = model_class.create!(title: "Edit Test")

      get lcp_ruby.edit_resource_path(lcp_slug: "documents", id: record.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit Test")
    end
  end

  describe "updating with a new file" do
    it "replaces the existing attachment" do
      record = model_class.create!(title: "Update Test")
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("original"),
        filename: "original.jpg",
        content_type: "image/jpeg"
      )
      record.photo.attach(blob)

      new_file = create_upload("new image", "new.jpg", "image/jpeg")
      patch lcp_ruby.resource_path(lcp_slug: "documents", id: record.id), params: {
        record: { title: "Updated", photo: new_file }
      }

      expect(response).to have_http_status(:redirect)
      record.reload
      expect(record.title).to eq("Updated")
      expect(record.photo).to be_attached
      expect(record.photo.blob.filename.to_s).to eq("new.jpg")
    end
  end

  describe "removing an attachment" do
    it "purges the attachment when remove flag is set" do
      record = model_class.create!(title: "Remove Test")
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("to remove"),
        filename: "remove.jpg",
        content_type: "image/jpeg"
      )
      record.photo.attach(blob)
      expect(record.photo).to be_attached

      patch lcp_ruby.resource_path(lcp_slug: "documents", id: record.id), params: {
        record: { title: "Remove Test", remove_photo: "1" }
      }

      expect(response).to have_http_status(:redirect)
      record.reload
      expect(record.photo).not_to be_attached
    end
  end

  describe "validation: oversized file rejected" do
    it "rejects a file exceeding max_size" do
      # photo has max_size: 5MB
      large_file = create_upload("x" * (6 * 1024 * 1024), "huge.jpg", "image/jpeg")

      post lcp_ruby.resources_path(lcp_slug: "documents"), params: {
        record: { title: "Large File", photo: large_file }
      }

      # Should re-render the form with errors
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("too large")
    end
  end

  describe "validation: wrong content type rejected" do
    it "rejects a file with disallowed content type" do
      # photo only allows image/jpeg, image/png, image/webp
      text_file = create_upload("not an image", "readme.txt", "text/plain")

      post lcp_ruby.resources_path(lcp_slug: "documents"), params: {
        record: { title: "Wrong Type", photo: text_file }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("invalid content type")
    end
  end

  describe "validation: max_files exceeded" do
    it "rejects when too many files attached" do
      files = 6.times.map do |i|
        create_upload("file #{i}", "file#{i}.pdf", "application/pdf")
      end

      post lcp_ruby.resources_path(lcp_slug: "documents"), params: {
        record: { title: "Too Many", files: files }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("too many files")
    end
  end

  describe "form rendering" do
    it "renders file_upload input for attachment field" do
      get lcp_ruby.new_resource_path(lcp_slug: "documents")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-file-upload")
      expect(response.body).to include("lcp-drop-zone")
    end

    it "renders multipart form" do
      get lcp_ruby.new_resource_path(lcp_slug: "documents")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('enctype="multipart/form-data"')
    end
  end

  private

  def create_upload(content, filename, content_type)
    file = Tempfile.new([ File.basename(filename, ".*"), File.extname(filename) ])
    file.binmode
    file.write(content)
    file.rewind

    Rack::Test::UploadedFile.new(file.path, content_type, false, original_filename: filename)
  end
end
