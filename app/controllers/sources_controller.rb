class SourcesController < ApplicationController
  before_action :load_source, only: [:show, :edit, :update]
  load_and_authorize_resource
  skip_authorize_resource :only => [:show, :index]

  def show
    @doc = Doc.find(@source.name)
    if current_user && current_user.publisher_id && @source.by_publisher?
      @publisher_option = PublisherOption.where(publisher_id: current_user.publisher_id, source_id: @source.id).first_or_create
    end

    render :show
  end

  def index
    @doc = Doc.find("sources")

    @groups = Group.includes(:sources).order("groups.id, sources.title")
  end

  def edit
    @doc = Doc.find(@source.name)
    if current_user && current_user.publisher_id && @source.by_publisher?
      @publisher_option = PublisherOption.where(publisher_id: current_user.publisher_id, source_id: @source.id).first_or_create
    end
    render :show
  end

  def update
    params[:source] ||= {}
    params[:source][:state_event] = params[:state_event] if params[:state_event]
    @source.update_attributes(safe_params)
    if @source.invalid?
      error_messages = @source.errors.full_messages.join(', ')
      flash.now[:alert] = "Please configure source #{@source.title}: #{error_messages}"
      @flash = flash
    end

    if params[:state_event]
      @groups = Group.includes(:sources).order("groups.id, sources.title")
      render :index
    else
      render :show
    end
  end

  protected

  def load_source
    @source = Source.where(name: params[:id]).first

    # raise error if source wasn't found
    fail ActiveRecord::RecordNotFound, "No record for \"#{params[:id]}\" found" if @source.blank?
  end

  private

  def safe_params
    params.require(:source).permit(:title,
                                   :group_id,
                                   :state_event,
                                   :private,
                                   :by_publisher,
                                   :queueable,
                                   :description,
                                   :workers,
                                   :queue,
                                   :rate_limiting,
                                   :staleness_week,
                                   :staleness_month,
                                   :staleness_year,
                                   :staleness_all,
                                   :cron_line,
                                   :timeout,
                                   :max_failed_queries,
                                   :tracked,
                                   :url,
                                   :url_with_type,
                                   :url_with_title,
                                   :related_works_url,
                                   :api_key,
                                   *@source.config_fields)
  end
end
