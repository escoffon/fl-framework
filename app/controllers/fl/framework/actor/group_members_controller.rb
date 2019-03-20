require_dependency "fl/framework/application_controller"

class Fl::Framework::Actor::GroupMembersController < ApplicationController
  include Fl::Framework::Controller::Helper
  include Fl::Framework::Controller::StatusError

  # before_action :authenticate_user!, except: [ :index, :show ]

  # Temporary
  
  def current_user()
    nil
  end
  
  # GET /actor/group_members
  # GET /actor/group_members.json
  def index
    service = Fl::Framework::Service::Actor::GroupMember.new(current_user, params, self)
    # because we hash the object, we use more extensive preloading than the default [ :group, :actor ];
    # for example, we preload the :owner association in :group, since it will be triggered by the default
    # to_hash. Note that we could hyperoptimize this by setting the :includes based on :to_hash, and
    # we may do it in the future to squeeze performance

    r = service.index({ includes: [ { group: [ :owner ] }, :actor ] }, query_params, pagination_params)
    respond_to do |format|
      format.html do
      end

      format.json do
        if r
          render :json => {
                   :group_members => hash_objects(r[:result], service.to_hash_params),
                   :_pg => r[:_pg]
                 }
        else
          error_response(generate_error_info(service))
        end
      end
    end
  end

  # GET /actor/group_members/1
  # GET /actor/group_members/1.json
  def show
    service = Fl::Framework::Service::Actor::GroupMember.new(current_user, params, self)
    @group_member = service.get_and_check(Fl::Framework::Access::Permission::Read)
    respond_to do |format|
      format.html do
      end

      format.json do
        if service.success?
          render :json => { :group_member => hash_one_object(@group_member, service.to_hash_params) }
        else
          error_response(generate_error_info(service, @group_member))
        end
      end
    end
  end

  # GET /actor/group_members/new
  def new
  end

  # GET /actor/group_members/1/edit
  def edit
  end

  # POST /actor/group_members
  # POST /actor/group_members.json
  def create
    service = Fl::Framework::Service::Actor::GroupMember.new(current_user, params, self)
    @group_member = service.create()
    if @group_member
      respond_to do |format|
        format.json do
          if service.success?
            render :json => { :group_member => hash_one_object(@group_member, service.to_hash_params) }
          else
            error_response(generate_error_info(service, @group_member))
          end
        end
      end
    else
      error_response(generate_error_info(service, @list))
    end
  end

  # PATCH/PUT /actor/group_members/1
  # PATCH/PUT /actor/group_members/1.json
  def update
    service = Fl::Framework::Service::Actor::GroupMember.new(current_user, params, self)
    @group_member = service.update()
    respond_to do |format|
      format.json do
        if @group_member && service.success?
          render :json => { :group_member => hash_one_object(@group_member, service.to_hash_params) }
        else
          error_response(generate_error_info(service, @group_member))
        end
      end
    end
  end

  # DELETE /actor/group_members/1
  # DELETE /actor/group_members/1.json
  def destroy
    service = Fl::Framework::Service::Actor::GroupMember.new(current_user, params, self)
    @group_member = service.get_and_check(Fl::Framework::Access::Permission::Delete)
    if @group_member && service.success?
      title = @group_member.title
      fingerprint = @group_member.fingerprint
      if @group_member.destroy
        respond_to do |format|
          format.json do
            status_response({
                              status: Fl::Framework::Service::OK,
                              message: tx('fl.framework.actor_group_member.controller.destroy.deleted',
                                          fingerprint: fingerprint, title: title)
                            })
          end
        end
      end
    else
      respond_to do |format|
        format.json do
          error_response(generate_error_info(service, @group_member))
        end
      end
    end
  end

  private

  # Never trust parameters from the scary internet, only allow the white list through.

  def query_params
    if params.has_key?(:group_id)
      # This is a nested resaoure call, and the query is run in the context of the master list
      
      qp = normalize_query_params.permit({ only_actors: [ ] }, { except_actors: [ ] },
                                         :created_after, :updated_after, :created_before, :updated_before,
                                         :order, :limit, :offset)
      qp[:only_groups] = [ params[:group_id] ]
    else
      qp = normalize_query_params.permit({ only_groups: [ ] }, { except_groups: [ ] },
                                         { only_actors: [ ] }, { except_actors: [ ] },
                                         :created_after, :updated_after, :created_before, :updated_before,
                                         :order, :limit, :offset)
    end

    qp
  end
end
