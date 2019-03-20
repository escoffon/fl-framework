require_dependency "fl/framework/application_controller"

class Fl::Framework::Actor::GroupsController < ApplicationController
  include Fl::Framework::Controller::Helper
  include Fl::Framework::Controller::StatusError

  # before_action :authenticate_user!, except: [ :index, :show ]

  # Temporary
  
  def current_user()
    nil
  end
  
  # GET /groups
  # GET /groups.json
  def index
    @service = Fl::Framework::Service::Actor::Group.new(current_user, params, self)
    r = @service.index({ }, query_params, pagination_params)
    respond_to do |format|
      format.html do
      end

      format.json do
        if r
          render :json => { :groups => hash_objects(r[:result], @service.to_hash_params), :_pg => r[:_pg] }
        else
          error_response(generate_error_info(@service))
        end
      end
    end
  end

  # GET /groups/1
  # GET /groups/1.json
  def show
    @service = Fl::Framework::Service::Actor::Group.new(current_user, params, self)
    @group = @service.get_and_check(Fl::Framework::Access::Permission::Read::NAME)
    respond_to do |format|
      format.html do
      end

      format.json do
        if @service.success?
          with_members = params[:with_members]
          render :json => { :group => hash_one_object(@group, show_to_hash_params) }
        else
          error_response(generate_error_info(@service, @group))
        end
      end
    end
  end

  # GET /groups/new
  def new
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  # POST /groups.json
  def create
    @service = Fl::Framework::Service::Actor::Group.new(current_user, params, self)
    @group = @service.create()
    if @group
      respond_to do |format|
        format.json do
          if @service.success?
            render :json => { :group => hash_one_object(@group, @service.to_hash_params) }
          else
            error_response(generate_error_info(@service, @group))
          end
        end
      end
    else
      error_response(generate_error_info(@service, @group))
    end
  end

  # PATCH/PUT /groups/1
  # PATCH/PUT /groups/1.json
  def update
    @service = Fl::Framework::Service::Actor::Group.new(current_user, params, self)
    @group = @service.update()
    respond_to do |format|
      format.json do
        if @group && @service.success?
          render :json => { :group => hash_one_object(@group, @service.to_hash_params) }
        else
          error_response(generate_error_info(@service, @group))
        end
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.json
  def destroy
    @service = Fl::Framework::Service::Actor::Group.new(current_user, params, self)
    @group = @service.get_and_check(Fl::Framework::Access::Permission::Delete::NAME)
    if @group && @service.success?
      name = @group.name
      fingerprint = @group.fingerprint
      if @group.destroy
        respond_to do |format|
          format.json do
            status_response({
                              status: Fl::Framework::Service::OK,
                              message: tx('fl.framework.actor_group.controller.destroy.deleted',
                                          fingerprint: fingerprint, name: name)
                            })
          end
        end
      end
    else
      respond_to do |format|
        format.json do
          error_response(generate_error_info(@service, @group))
        end
      end
    end
  end

  # POST /groups/1/add_actor
  # POST /groups/1/add_actor.json
  def add_actor
    @service = Fl::Framework::Service::Actor::Group.new(current_user, params, self)
    @group, @group_member = @service.add_actor()
    respond_to do |format|
      format.json do
        if @group && @group_member && @service.success?
          if @group.save
            # We need to reload the group items to pick up the sort order, which was set by @group.save

            @group_member.reload
            render :json => {
                     :group_member => hash_one_object(@group_member, @service.to_hash_params)
                   }
          else
            error_response(generate_error_info(@service, @group))
          end
        else
          error_response(generate_error_info(@service, @group))
        end
      end
    end
  end

  private

  # Never trust parameters from the scary internet, only allow the white group through.

  def query_params
    normalize_query_params.permit({ only_owners: [ ] }, { except_owners: [ ] },
                                  :created_after, :updated_after, :created_before, :updated_before,
                                  :order, :limit, :offset)
  end

  def show_to_hash_params()
    hp = @service.to_hash_params
    if params[:with_members]
      if hp.has_key?(:include)
        # Note that to be really anal we should drop :group_members from :except, and also process :only
        
        hp[:include] = [ hp[:include] ] unless hp[:include].is_a?(Array)
        hp[:include] |= [ :members ]
      else
        hp[:include] = [ :members ]
      end
    end

    hp
  end
end
