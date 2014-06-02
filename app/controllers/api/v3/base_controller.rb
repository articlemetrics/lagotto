class Api::V3::BaseController < ActionController::Base
  # include base controller methods
  include Authenticable

  respond_to :json, :xml

  before_filter :default_format_json, :authenticate_user_from_token!, :cors_preflight_check
  after_filter :cors_set_access_control_headers
end
