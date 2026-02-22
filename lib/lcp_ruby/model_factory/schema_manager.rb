module LcpRuby
  module ModelFactory
    class SchemaManager
      attr_reader :model_definition

      def initialize(model_definition)
        @model_definition = model_definition
      end

      def ensure_table!
        table = model_definition.table_name

        if ActiveRecord::Base.connection.table_exists?(table)
          update_table!
        else
          create_table!
        end
      end

      private

      def create_table!
        table = model_definition.table_name
        fields = model_definition.fields
        associations = model_definition.associations
        timestamps = model_definition.timestamps?

        ActiveRecord::Base.connection.create_table(table) do |t|
          fields.each do |field|
            next if field.attachment?
            next if field.virtual?
            add_column_to_table(t, field)
          end

          associations.select { |a| a.type == "belongs_to" }.each do |assoc|
            unless fields.any? { |f| f.name == assoc.foreign_key }
              t.bigint assoc.foreign_key, null: !assoc.required
              t.index assoc.foreign_key
            end

            if assoc.polymorphic
              type_col = "#{assoc.name}_type"
              unless fields.any? { |f| f.name == type_col }
                t.string type_col
                t.index [ assoc.foreign_key, type_col ]
              end
            end
          end

          if model_definition.custom_fields_enabled?
            t.column :custom_data, LcpRuby.json_column_type, default: {}
          end

          t.timestamps if timestamps
        end

        if model_definition.custom_fields_enabled? && LcpRuby.postgresql?
          connection = ActiveRecord::Base.connection
          connection.execute(
            "CREATE INDEX IF NOT EXISTS #{custom_data_index_name(table)} " \
            "ON #{connection.quote_table_name(table)} USING GIN (custom_data)"
          )
        end

        apply_positioning_constraints!(table) if model_definition.positioned?
      end

      def update_table!
        table = model_definition.table_name
        connection = ActiveRecord::Base.connection
        existing_columns = connection.columns(table).map(&:name)

        model_definition.fields.each do |field|
          next if field.attachment?
          next if field.virtual?
          column_name = field.name
          next if existing_columns.include?(column_name)

          options = build_column_options(field)
          connection.add_column(table, column_name, field.column_type, **options)
        end

        model_definition.associations.select { |a| a.type == "belongs_to" }.each do |assoc|
          fk = assoc.foreign_key
          next if existing_columns.include?(fk)
          next if model_definition.fields.any? { |f| f.name == fk }

          connection.add_column(table, fk, :bigint, null: !assoc.required)

          unless connection.index_exists?(table, fk)
            connection.add_index(table, fk)
          end

          if assoc.polymorphic
            type_col = "#{assoc.name}_type"
            unless existing_columns.include?(type_col) || model_definition.fields.any? { |f| f.name == type_col }
              connection.add_column(table, type_col, :string)

              unless connection.index_exists?(table, [ fk, type_col ])
                connection.add_index(table, [ fk, type_col ])
              end
            end
          end
        end

        if model_definition.custom_fields_enabled? && !existing_columns.include?("custom_data")
          connection.add_column(table, "custom_data", LcpRuby.json_column_type, default: {})

          if LcpRuby.postgresql? && !connection.index_exists?(table, :custom_data, using: :gin)
            connection.execute(
              "CREATE INDEX IF NOT EXISTS #{custom_data_index_name(table)} " \
              "ON #{connection.quote_table_name(table)} USING GIN (custom_data)"
            )
          end
        end

        if model_definition.timestamps?
          %w[created_at updated_at].each do |ts_col|
            unless existing_columns.include?(ts_col)
              connection.add_column(table, ts_col, :datetime, precision: 6)
            end
          end
        end

        apply_positioning_constraints!(table) if model_definition.positioned?
      end

      def apply_positioning_constraints!(table)
        connection = ActiveRecord::Base.connection
        col = model_definition.positioning_field

        # Ensure NOT NULL on position column (for existing tables where the column may be nullable)
        if connection.column_exists?(table, col)
          column = connection.columns(table).find { |c| c.name == col }
          if column&.null
            connection.execute(
              "UPDATE #{connection.quote_table_name(table)} SET #{connection.quote_column_name(col)} = 0 WHERE #{connection.quote_column_name(col)} IS NULL"
            )
            connection.change_column_null(table, col, false)
          end
        end

        # Add a unique index on [scope_columns..., position_column] for databases
        # that support row-level locking (PostgreSQL, MySQL). The positioning gem
        # uses negative intermediate positions during reorder (never actual duplicates),
        # so the unique constraint is safe as long as concurrent transactions are
        # serialized via SELECT ... FOR UPDATE — which SQLite does not support.
        add_positioning_index!(table, connection) unless sqlite?(connection)
      end

      def add_positioning_index!(table, connection)
        col = model_definition.positioning_field
        scope_cols = model_definition.positioning_scope
        index_columns = scope_cols + [ col ]
        index_name = "idx_#{table}_positioning"

        return if connection.index_exists?(table, index_columns, unique: true)

        begin
          connection.add_index(table, index_columns, unique: true, name: index_name)
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
          model_class_name = "LcpRuby::Dynamic::#{model_definition.name.classify}"
          heal_method = "heal_#{col}_column!"
          Rails.logger.warn(
            "[LcpRuby] Could not create unique positioning index on #{table} " \
            "(#{index_columns.join(', ')}): #{e.message}. " \
            "This usually means the table has duplicate position values. " \
            "Run `#{model_class_name}.#{heal_method}` in the Rails console to fix existing data, then restart."
          )
        end
      end

      def sqlite?(connection)
        connection.adapter_name.downcase.include?("sqlite")
      end

      def add_column_to_table(t, field)
        options = build_column_options(field)
        col_type = field.column_type

        t.column field.name, col_type, **options
      end

      def custom_data_index_name(table)
        name = "idx_#{table}_custom_data"
        return name if name.length <= 63

        # PostgreSQL limit is 63 chars; truncate and append hash for uniqueness
        hash = Digest::SHA256.hexdigest(table)[0, 8]
        "idx_#{table[0, 63 - 18]}_cd_#{hash}"
      end

      def build_column_options(field)
        options = {}

        # Apply type-level column options first (type defaults)
        if field.type_definition
          type_opts = field.type_definition.column_options
          options[:limit] = type_opts[:limit] if type_opts[:limit]
          options[:precision] = type_opts[:precision] if type_opts[:precision]
          options[:scale] = type_opts[:scale] if type_opts[:scale]
          options[:null] = type_opts[:null] if type_opts.key?(:null)
        end

        # Overlay field-level column options (field wins)
        col_opts = field.column_options
        options[:limit] = col_opts[:limit] if col_opts[:limit]
        options[:precision] = col_opts[:precision] if col_opts[:precision]
        options[:scale] = col_opts[:scale] if col_opts[:scale]
        options[:null] = col_opts[:null] if col_opts.key?(:null)
        options[:default] = field.default if field.default && !field.default.is_a?(Hash)

        options
      end
    end
  end
end
