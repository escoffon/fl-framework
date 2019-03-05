require_dependency "fl/framework/application_controller"

module Fl::Framework
  class ListsController < ApplicationController
    include Fl::Framework::Controller::Helper
    include Fl::Framework::Controller::StatusError

    # before_action :authenticate_user!, except: [ :index, :show ]

    # Temporary
    
    def current_user()
      nil
    end
    
    # GET /lists
    # GET /lists.json
    def index
      @service = Fl::Framework::Service::List.new(current_user, params, self)
      r = @service.index({ includes: [ ] }, query_params, pagination_params)
      respond_to do |format|
        format.html do
        end

        format.json do
          if r
            render :json => { :lists => hash_objects(r[:result], @service.to_hash_params), :_pg => r[:_pg] }
          else
            error_response(generate_error_info(@service))
          end
        end
      end
    end

    # GET /lists/1
    # GET /lists/1.json
    def show
      @service = Fl::Framework::Service::List.new(current_user, params, self)
      @list = @service.get_and_check(Fl::Framework::Access::Grants::READ)
      respond_to do |format|
        format.html do
        end

        format.json do
          if @service.success?
            with_list_items = params[:with_list_items]
            render :json => { :list => hash_one_object(@list, show_to_hash_params) }
          else
            error_response(generate_error_info(@service, @list))
          end
        end
      end
    end

    # GET /lists/new
    def new
    end

    # GET /lists/1/edit
    def edit
    end

    # POST /lists
    # POST /lists.json
    def create
      @service = Fl::Framework::Service::List.new(current_user, params, self)
      @list = @service.create()
      if @list
        respond_to do |format|
          format.json do
            if @service.success?
              render :json => { :list => hash_one_object(@list, @service.to_hash_params) }
            else
              error_response(generate_error_info(@service, @list))
            end
          end
        end
      else
        error_response(generate_error_info(@service, @list))
      end
    end

    # PATCH/PUT /lists/1
    # PATCH/PUT /lists/1.json
    def update
      @service = Fl::Framework::Service::List.new(current_user, params, self)
      @list = @service.update()
      respond_to do |format|
        format.json do
          if @list && @service.success?
            render :json => { :list => hash_one_object(@list, @service.to_hash_params) }
          else
            error_response(generate_error_info(@service, @list))
          end
        end
      end
    end

    # DELETE /lists/1
    # DELETE /lists/1.json
    def destroy
      @service = Fl::Framework::Service::List.new(current_user, params, self)
      @list = @service.get_and_check(Fl::Framework::Access::Grants::DESTROY)
      if @list && @service.success?
        title = @list.title
        fingerprint = @list.fingerprint
        if @list.destroy
          respond_to do |format|
            format.json do
              status_response({
                                status: Fl::Framework::Service::OK,
                                message: tx('fl.framework.list.controller.destroy.deleted',
                                            fingerprint: fingerprint, title: title)
                              })
            end
          end
        end
      else
        respond_to do |format|
          format.json do
            error_response(generate_error_info(@service, @list))
          end
        end
      end
    end

    # POST /lists/1/add_object
    # POST /lists/1/add_object.json
    def add_object
      @service = Fl::Framework::Service::List.new(current_user, params, self)
      @list, @list_item = @service.add_object()
      respond_to do |format|
        format.json do
          if @list && @list_item && @service.success?
            if @list.save
              # We need to reload the list items to pick up the sort order, which was set by @list.save

              @list_item.reload
              render :json => {
                       :list_item => hash_one_object(@list_item, @service.to_hash_params)
                     }
            else
              error_response(generate_error_info(@service, @list))
            end
          else
            error_response(generate_error_info(@service, @list))
          end
        end
      end
    end

    private

    # Never trust parameters from the scary internet, only allow the white list through.

    def query_params
      normalize_query_params.permit({ only_owners: [ ] }, { except_owners: [ ] },
                                    :created_after, :updated_after, :created_before, :updated_before,
                                    :order, :limit, :offset)
    end

    def show_to_hash_params()
      hp = @service.to_hash_params
      if params[:with_list_items]
        if hp.has_key?(:include)
          # Note that to be really anal we should drop :list_items from :except, and also process :only
          
          hp[:include] = [ hp[:include] ] unless hp[:include].is_a?(Array)
          hp[:include] |= [ :list_items ]
        else
          hp[:include] = [ :list_items ]
        end
      end

      hp
    end
  end
end
