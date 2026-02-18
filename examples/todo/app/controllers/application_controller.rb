class ApplicationController < ActionController::Base
  def current_user
    @current_user ||= OpenStruct.new(id: 1, lcp_role: ["admin"], name: "Admin User")
  end
  helper_method :current_user
end
