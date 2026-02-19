module LcpRuby
  module Types
    class BuiltInTypes
      DEFINITIONS = {
        "email" => {
          name: "email",
          base_type: "string",
          transforms: %w[strip downcase],
          validations: [
            { "type" => "format", "options" => { "with" => '\A[^@\s]+@[^@\s]+\z', "allow_blank" => true } }
          ],
          input_type: "email",
          renderer: "email_link",
          column_options: { limit: 255 }
        },
        "phone" => {
          name: "phone",
          base_type: "string",
          transforms: %w[strip normalize_phone],
          validations: [
            { "type" => "format", "options" => { "with" => '\A\+?\d{7,15}\z', "allow_blank" => true } }
          ],
          input_type: "tel",
          renderer: "phone_link",
          column_options: { limit: 50 }
        },
        "url" => {
          name: "url",
          base_type: "string",
          transforms: %w[strip normalize_url],
          validations: [
            { "type" => "format", "options" => { "with" => '\A(https?|ftp)://[^\s/$.?#].[^\s]*\z', "allow_blank" => true } }
          ],
          input_type: "url",
          renderer: "url_link",
          column_options: { limit: 2048 }
        },
        "color" => {
          name: "color",
          base_type: "string",
          transforms: %w[strip downcase],
          validations: [
            { "type" => "format", "options" => { "with" => '\A#[0-9a-f]{6}\z', "allow_blank" => true } }
          ],
          input_type: "color",
          renderer: "color_swatch",
          column_options: { limit: 7 }
        }
      }.freeze

      class << self
        def register_all!
          DEFINITIONS.each do |name, attrs|
            type_def = TypeDefinition.new(**attrs)
            TypeRegistry.register(name, type_def)
          end
        end
      end
    end
  end
end
