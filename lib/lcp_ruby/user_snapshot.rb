module LcpRuby
  module UserSnapshot
    def self.capture(user)
      return nil unless user

      snapshot = { "id" => user.id }
      snapshot["email"] = user.email if user.respond_to?(:email)
      snapshot["name"] = user.name if user.respond_to?(:name)
      if user.respond_to?(LcpRuby.configuration.role_method)
        snapshot["role"] = user.send(LcpRuby.configuration.role_method)
      end
      snapshot
    end
  end
end
