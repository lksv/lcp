# frozen_string_literal: true

require "rails/generators"

module LcpRuby
  module Generators
    class GapfreeSequencesGenerator < Rails::Generators::Base
      source_root File.expand_path("templates/gapfree_sequences", __dir__)

      desc "Generates YAML metadata files for the gapfree sequences counter table (model, permissions)"

      def copy_model
        template "model.yml", "config/lcp_ruby/models/gapfree_sequence.yml"
      end

      def copy_permissions
        template "permissions.yml", "config/lcp_ruby/permissions/gapfree_sequence.yml"
      end

      def show_post_install_message
        say ""
        say "LCP Ruby gapfree sequences installed!", :green
        say ""
        say "Next steps:"
        say "  1. Start server — the counter table is created automatically at boot"
        say "  2. Add sequence fields to your model YAML:"
        say "     fields:"
        say "       - name: invoice_number"
        say "         type: string"
        say "         sequence:"
        say "           scope: [_year]"
        say '           format: "INV-%{_year}-%{sequence:04d}"'
        say ""
        say "Optional:"
        say "  - Create a presenter for the gapfree_sequence model to manage counters via UI"
        say "  - Use rake lcp_ruby:gapfree_sequences:list to inspect counter values"
        say "  - Use rake lcp_ruby:gapfree_sequences:set to set a counter value"
        say ""
      end
    end
  end
end
