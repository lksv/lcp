class ApplicationController < ActionController::Base
  def current_user
    role = session[:role] || "admin"
    @current_user ||= OpenStruct.new(id: 1, lcp_role: [role], name: "Demo User (#{role})")
  end
  helper_method :current_user
end
