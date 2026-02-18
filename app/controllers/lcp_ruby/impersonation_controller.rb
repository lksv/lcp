module LcpRuby
  class ImpersonationController < ApplicationController
    skip_before_action :set_presenter_and_model
    skip_before_action :authorize_presenter_access

    def create
      unless can_impersonate_current_user?
        redirect_back fallback_location: "/", allow_other_host: false, alert: "You are not authorized to impersonate roles."
        return
      end

      role = params[:role]
      if role.blank?
        redirect_back fallback_location: "/", allow_other_host: false, alert: "No role specified."
        return
      end

      unless available_roles_for_impersonation.include?(role)
        redirect_back fallback_location: "/", allow_other_host: false, alert: "Role '#{role}' is not a valid role."
        return
      end

      session[:lcp_impersonate_role] = role
      redirect_back fallback_location: "/", allow_other_host: false, notice: "Impersonating role: #{role}"
    end

    def destroy
      session.delete(:lcp_impersonate_role)
      redirect_back fallback_location: "/", allow_other_host: false, notice: "Stopped impersonation."
    end
  end
end
