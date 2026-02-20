# frozen_string_literal: true

namespace :lcp_ruby do
  desc "Create an admin user for LCP Ruby built-in authentication"
  task create_admin: :environment do
    unless LcpRuby.configuration.authentication == :built_in
      abort "Error: LCP Ruby authentication mode is not :built_in. " \
            "Set config.authentication = :built_in in your initializer."
    end

    email = ENV["EMAIL"]
    password = ENV["PASSWORD"]
    name = ENV["NAME"] || "Admin"
    roles = (ENV["ROLES"] || "admin").split(",").map(&:strip)

    if email.blank? || password.blank?
      abort "Usage: rake lcp_ruby:create_admin EMAIL=admin@example.com PASSWORD=secret123 [NAME=Admin] [ROLES=admin]"
    end

    user = LcpRuby::User.find_or_initialize_by(email: email)
    user.assign_attributes(
      name: name,
      password: password,
      password_confirmation: password,
      lcp_role: roles,
      active: true
    )

    if user.save
      status = user.previously_new_record? ? "Created" : "Updated"
      puts "#{status} admin user: #{email} (roles: #{roles.join(', ')})"
    else
      abort "Failed to save user: #{user.errors.full_messages.join(', ')}"
    end
  end
end
