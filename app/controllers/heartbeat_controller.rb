class HeartbeatController < ApplicationController
  # include base controller methods
  include Authenticable

  respond_to :json

  before_filter :default_format_json, :cors_preflight_check
  after_filter :cors_set_access_control_headers

  def index
    @status = Status.new
  end
end
