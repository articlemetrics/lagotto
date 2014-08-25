class DocsController < ApplicationController
  respond_to :html

  def index
    @doc = Doc.find("index")
    render :show
  end

  def show
    @doc = Doc.find(params[:id])
  end
end
