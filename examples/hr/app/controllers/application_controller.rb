class ApplicationController < ActionController::Base
  def current_user
    role = session[:role] || "admin"
    @current_user ||= OpenStruct.new(
      id: 1,
      lcp_role: [role],
      lcp_groups: [],
      name: "Demo User (#{role})",
      email: "demo@example.com",
      organization_unit_id: 1,
      employee_id: 1
    )
  end
  helper_method :current_user
end
