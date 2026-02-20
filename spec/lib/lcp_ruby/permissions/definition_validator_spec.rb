require "spec_helper"

RSpec.describe LcpRuby::Permissions::DefinitionValidator do
  describe "#validate" do
    def validate(hash)
      described_class.new(hash).validate
    end

    context "with valid definition" do
      it "returns no errors for a complete valid definition" do
        hash = {
          "roles" => {
            "admin" => {
              "crud" => %w[index show create update destroy],
              "fields" => { "readable" => "all", "writable" => "all" }
            },
            "viewer" => {
              "crud" => %w[index show],
              "fields" => { "readable" => "all", "writable" => [] }
            }
          },
          "default_role" => "viewer",
          "field_overrides" => {},
          "record_rules" => []
        }

        expect(validate(hash)).to be_empty
      end

      it "returns no errors for minimal definition" do
        hash = { "roles" => { "admin" => {} } }
        expect(validate(hash)).to be_empty
      end
    end

    context "with missing roles" do
      it "returns an error when roles is not a Hash" do
        errors = validate({ "roles" => "admin" })
        expect(errors).to include(a_string_matching("must have a 'roles' key"))
      end

      it "returns an error when roles key is absent" do
        errors = validate({})
        expect(errors).to include(a_string_matching("must have a 'roles' key"))
      end
    end

    context "with invalid crud actions" do
      it "returns an error for unknown actions" do
        hash = {
          "roles" => {
            "admin" => { "crud" => %w[index show publish] }
          }
        }

        errors = validate(hash)
        expect(errors).to include(a_string_matching("unknown actions: publish"))
      end

      it "returns an error when crud is not an Array" do
        hash = {
          "roles" => {
            "admin" => { "crud" => "all" }
          }
        }

        errors = validate(hash)
        expect(errors).to include(a_string_matching("crud must be an Array"))
      end
    end

    context "with invalid fields" do
      it "returns an error when fields is not a Hash" do
        hash = {
          "roles" => {
            "admin" => { "fields" => "all" }
          }
        }

        errors = validate(hash)
        expect(errors).to include(a_string_matching("fields must be a Hash"))
      end

      it "returns an error when readable is not 'all' or Array" do
        hash = {
          "roles" => {
            "admin" => {
              "fields" => { "readable" => "some" }
            }
          }
        }

        errors = validate(hash)
        expect(errors).to include(a_string_matching("fields.readable must be 'all' or an Array"))
      end

      it "allows readable: all" do
        hash = {
          "roles" => {
            "admin" => {
              "fields" => { "readable" => "all", "writable" => [] }
            }
          }
        }

        expect(validate(hash)).to be_empty
      end
    end

    context "with invalid default_role" do
      it "returns an error when default_role is not a String" do
        hash = {
          "roles" => { "admin" => {} },
          "default_role" => 42
        }

        errors = validate(hash)
        expect(errors).to include(a_string_matching("default_role must be a String"))
      end
    end

    context "with invalid field_overrides" do
      it "returns an error when field_overrides is not a Hash" do
        hash = {
          "roles" => { "admin" => {} },
          "field_overrides" => [ "title" ]
        }

        errors = validate(hash)
        expect(errors).to include(a_string_matching("field_overrides must be a Hash"))
      end
    end

    context "with invalid record_rules" do
      it "returns an error when record_rules is not an Array" do
        hash = {
          "roles" => { "admin" => {} },
          "record_rules" => "deny"
        }

        errors = validate(hash)
        expect(errors).to include(a_string_matching("record_rules must be an Array"))
      end
    end
  end
end
