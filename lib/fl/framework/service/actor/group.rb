require 'fl/framework/actor'
require 'fl/framework/service/base'

module Fl::Framework::Service::Actor
  # Service object for actor groups.

  class Group < Fl::Framework::Service::Base
    self.model_class = Fl::Framework::Actor::Group

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def create_params(p = nil)
      strong_params(p).require(:fl_framework_actor_group).permit(:name, :note, :owner, { actors: [ ] })
    end

    # Get update parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the update parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.

    def update_params(p = nil)
      strong_params(p).require(:fl_framework_actor_group).permit(:name, :note, :owner, { actors: [ ] })
    end

    # Get `to_hash` parameters.
    # Override the method here if you need to customize the `to_hash` permitted parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the `to_hash`
    #  parameters subset. If `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the `to_hash` parameters.

    def to_hash_params(p = nil)
      super(p)
    end

    # Add an actor to the group.
    # Calls {Fl::Framework::Actor::Group#add_actor} and returns the added group member.
    # If the operation fails, it sets the status to {Fl::Framework::Service::UNPROCESSABLE_ENTITY}
    # and loads a message and the **:details** key in the error status from the object's **errors** 
    # The target for the `add_object` method is obtained by a lookup using the **:id** submission parameter.
    #
    # The method calls {#allow_op?} for `opts[:permission]` to confirm that the
    # service's *actor* has permission to add an object (it requests the
    # {Fl::Framework::Actor::Permission::ManageMembers}) permission).
    # If the permission is not granted, `nil` is returned.
    #
    # @param opts [Hash] Options to the method.
    # @option opts [Symbol,String] :idname The name of the key in {#params} that contains the object
    #  identifier.
    #  Defaults to **:id**.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to the object's
    #  initializer. If not present or `nil`, use the value returned by {#add_actor_params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate subclass of {Fl::CAPTCHA::Base}
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to the initializer for {Fl::CAPTCHA::Base}.
    # @option opts [Symbol,String,Fl::Framework::Access::Permission,Class] :permission The permission
    #  to request in order to complete the operation.
    #  See {Fl::Framework::Access::Helper.permission_name}.
    #  Defaults to {Fl::Framework::Actor::Permission::ManageMembers::NAME}.
    # @option opts [Object] :context The context to pass to the access checker method {#class_allow_op?}.
    #  The special value **:params** (a Symbol named **params**) indicates that the create parameters are
    #  to be passed as the context.
    #  Defaults to **:params**.
    #
    # @return [Array] Returns an array containing two elements:
    #
    #  0. The target group object (an instance of {Fl::Framework::Actor::Group}).
    #  1. The group member returned by the `add_actor` call; this is an instance of
    #     {Fl::Framework::Actor::GroupMember}.

    def add_actor(opts = {})
      list = nil
      li = nil
      
      begin
        p = (opts[:params]) ? opts[:params].to_h : add_actor_params(self.params).to_h
        op = (opts[:permission]) ? opts[:permission] : Fl::Framework::Actor::Permission::ManageMembers::NAME
        #ctx = if opts.has_key?(:context)
        #        (opts[:context] == :params) ? p : opts[:context]
        #      else
        # This is equivalent to setting the default to :params
        #        p
        #      end
        idname = (opts[:idname]) ? opts[:idname].to_sym : :id

        group = get_and_check(op, idname)
        if group && success?
          rs = verify_captcha(opts[:captcha], p)
          if rs['success']
            gm = group.add_actor(p[:actor], p[:title], p[:note])
          else
            gm = nil
          end
        else
          gm = nil
        end
      rescue => x
        set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY, x.message)
      end


      [ group, gm ]
    end

    protected

    # Build a query to list instances of Fl::Framework::Actor::Group.
    # This method makes a call to the class method `build_query`, which you will have to define.
    #
    # @param query_opts [Hash] A hash of query options.
    #
    # @return [ActiveRecord::Relation, nil] Returns an instance of ActiveRecord::Relation, or `nil`
    #  on error.

    def index_query(query_opts = {})
      Fl::Framework::Actor::Group.build_query(query_opts)
    end

    private
  
    def add_actor_params(p = nil)
      pp = strong_params(p).fetch(:fl_framework_actor_group, {}).permit(:actor, :title, :note)

      # we execute this statement to trigger an exception if :actor is missing
      rp = pp.require(:actor)
      
      pp
    end
  end
end
