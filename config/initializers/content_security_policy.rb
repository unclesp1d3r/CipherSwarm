# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline
    if Rails.env.test?
      # Allow connections to any localhost port — testcontainers tusd binds to random ports
      policy.connect_src :self, :ws, :wss, "http://localhost:*", "http://127.0.0.1:*"
    else
      policy.connect_src :self, :ws, :wss
    end
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self
  end

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end
