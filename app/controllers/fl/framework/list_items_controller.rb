require_dependency "fl/framework/application_controller"

module Fl::Framework
  class ListItemsController < ApplicationController
    include Fl::Framework::Controller::Helper
    include Fl::Framework::Controller::StatusError

    # before_action :authenticate_user!, except: [ :index, :show ]

    # Temporary
    
    def current_user()
      nil
    end
    
    # GET /list_items
    # GET /list_items.json
    def index
      service = Fl::Framework::Service::ListItem.new(current_user, params, self)
      r = service.index({ includes: [ ] }, query_params, pagination_params)
      respond_to do |format|
        format.html do
        end

        format.json do
          if r
            render :json => {
                     :list_items => hash_objects(r[:result], service.to_hash_params),
                     :_pg => r[:_pg]
                   }
          else
            error_response(generate_error_info(service))
          end
        end
      end
    end

    # GET /list_items/1
    # GET /list_items/1.json
    def show
      service = Fl::Framework::Service::ListItem.new(current_user, params, self)
      @list_item = service.get_and_check(Fl::Framework::Access::Permission::Read)
      respond_to do |format|
        format.html do
        end

        format.json do
          if service.success?
            render :json => { :list_item => hash_one_object(@list_item, service.to_hash_params) }
          else
            error_response(generate_error_info(service, @list_item))
          end
        end
      end
    end

    # GET /list_items/new
    def new
    end

    # GET /list_items/1/edit
    def edit
    end

    # POST /list_items
    # POST /list_items.json
    def create
      service = Fl::Framework::Service::ListItem.new(current_user, params, self)
      @list_item = service.create()
      if @list_item
        respond_to do |format|
          format.json do
            if service.success?
              render :json => { :list_item => hash_one_object(@list_item, service.to_hash_params) }
            else
              error_response(generate_error_info(service, @list_item))
            end
          end
        end
      else
        error_response(generate_error_info(service, @list))
      end
    end

    # PATCH/PUT /list_items/1
    # PATCH/PUT /list_items/1.json
    def update
      service = Fl::Framework::Service::ListItem.new(current_user, params, self)
      @list_item = service.update()
      respond_to do |format|
        format.json do
          if @list_item && service.success?
            render :json => { :list_item => hash_one_object(@list_item, service.to_hash_params) }
          else
            error_response(generate_error_info(service, @list_item))
          end
        end
      end
    end

    # DELETE /list_items/1
    # DELETE /list_items/1.json
    def destroy
      service = Fl::Framework::Service::ListItem.new(current_user, params, self)
      @list_item = service.get_and_check(Fl::Framework::Access::Permission::Delete)
      if @list_item && service.success?
        name = @list_item.name
        fingerprint = @list_item.fingerprint
        if @list_item.destroy
          respond_to do |format|
            format.json do
              status_response({
                                status: Fl::Framework::Service::OK,
                                message: tx('fl.framework.list_item.controller.destroy.deleted',
                                            fingerprint: fingerprint, name: name)
                              })
            end
          end
        end
      else
        respond_to do |format|
          format.json do
            error_response(generate_error_info(service, @list_item))
          end
        end
      end
    end

    private

    # Never trust parameters from the scary internet, only allow the white list through.

    def query_params
      if params.has_key?(:list_id)
        # This is a nested resaoure call, and the query is run in the context of the master list
        
        qp = normalize_query_params.permit({ only_listables: [ ] }, { except_listables: [ ] },
                                           { only_owners: [ ] }, { except_owners: [ ] },
                                           :created_after, :updated_after, :created_before, :updated_before,
                                           :order, :limit, :offset)
        qp[:only_lists] = [ "#{Fl::Framework::List::List.name}/#{params[:list_id]}" ]
      else
        qp = normalize_query_params.permit({ only_lists: [ ] }, { except_lists: [ ] },
                                           { only_listables: [ ] }, { except_listables: [ ] },
                                           { only_owners: [ ] }, { except_owners: [ ] },
                                           :created_after, :updated_after, :created_before, :updated_before,
                                           :order, :limit, :offset)
      end

      qp
    end
  end
end
