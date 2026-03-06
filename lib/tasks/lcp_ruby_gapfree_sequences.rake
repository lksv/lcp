namespace :lcp_ruby do
  namespace :gapfree_sequences do
    desc "List all gapfree sequence counters"
    task list: :environment do
      rows = LcpRuby::Sequences::SequenceManager.list

      if rows.empty?
        puts "No sequence counters found."
        next
      end

      puts format("%-20s %-20s %-30s %s", "Model", "Field", "Scope Key", "Current Value")
      puts "-" * 80
      rows.each do |row|
        puts format("%-20s %-20s %-30s %d", row.seq_model, row.seq_field, row.scope_key, row.current_value)
      end
    end

    desc "Set a gapfree sequence counter value (MODEL=invoice FIELD=invoice_number SCOPE=_year:2026 VALUE=3500)"
    task set: :environment do
      model = ENV.fetch("MODEL") { abort "MODEL is required (e.g., MODEL=invoice)" }
      field = ENV.fetch("FIELD") { abort "FIELD is required (e.g., FIELD=invoice_number)" }
      value = ENV.fetch("VALUE") { abort "VALUE is required (e.g., VALUE=3500)" }.to_i
      scope_str = ENV.fetch("SCOPE", "_global")

      scope = if scope_str == "_global"
        {}
      else
        scope_str.split("/").each_with_object({}) do |pair, hash|
          key, val = pair.split(":", 2)
          hash[key] = val
        end
      end

      row = LcpRuby::Sequences::SequenceManager.set(model: model, field: field, scope: scope, value: value)
      puts "Counter set: #{row.seq_model}/#{row.seq_field} [#{row.scope_key}] = #{row.current_value}"
    end
  end
end
