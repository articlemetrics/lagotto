class Api::V7::SourcesController < Api::BaseController
  def index
    collection = Source.active.includes(:group)
    collection = collection.query(params[:q]) if params[:q]
    if params[:id].present?
      collection = collection.where(name: params[:id])
    end
    if params[:group_id].present? && group = cached_group(params[:group_id])
      collection = collection.where(group_id: group.id)
      @groups = { params[:group_id] => collection.where(group_id: group.id).count }
    else
      groups = collection.where.not(group_id: nil).group(:group_id).count
      group_names = cached_group_names
      @groups = groups.map { |k,v| [group_names[k], v] }.to_h
    end

    @sources = collection.decorate
  end

  def show
    source = Source.where(name: params[:id]).first
    fail ActiveRecord::RecordNotFound unless source.present?

    @source = source.decorate
  end
end
