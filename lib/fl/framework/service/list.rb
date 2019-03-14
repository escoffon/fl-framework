require 'fl/framework/list'
require 'fl/framework/service/base'

module Fl::Framework::Service
  # Service object for lists.

  class List < Fl::Framework::Service::Base
    self.model_class = Fl::Framework::List::List

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def create_params(p = nil)
      strong_params(p).require(:fl_framework_list).permit(:title, :caption, :owner, :default_readony_state,
                                                          :list_display_preferences)
    end

    # Get update parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the update parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.

    def update_params(p = nil)
      strong_params(p).require(:fl_framework_list).permit(:title, :caption, :owner, :default_readony_state,
                                                          :list_display_preferences)
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

    # Add an object to the list.
    # Calls {Fl::Framework::List::List#add_object} and returns the added list item.
    # If the operation fails, it sets the status to {Fl::Framework::Service::UNPROCESSABLE_ENTITY}
    # and loads a message and the **:details** key in the error status from the object's **errors** 
    # The target for the `add_object` method is obtained by a lookup using the **:id** submission parameter.
    #
    # The method calls {#allow_op?} for `opts[:permission]` to confirm that the
    # service's *actor* has permission to add an object (it requests `ADD_ITEM` permission).
    # If the permission is not granted, `nil` is returned.
    #
    # @param opts [Hash] Options to the method.
    # @option opts [Symbol,String] :idname The name of the key in {#params} that contains the object
    #  identifier.
    #  Defaults to **:id**.
    # @option opts [Hash,ActionController::Parameters] :params The parameters to pass to the object's
    #  initializer. If not present or `nil`, use the value returned by {#step_params}.
    # @option opts [Boolean,Hash] :captcha If this option is present and is either `true` or a hash,
    #  the method does a CAPTCHA validation using an appropriate subclass of {Fl::CAPTCHA::Base}
    #  (typically {Fl::Google::RECAPTCHA}, which implements
    #  {https://www.google.com/recaptcha/intro Google reCAPTCHA}).
    #  If the value is a hash, it is passed to the initializer for {Fl::CAPTCHA::Base}.
    # @option opts [Symbol,String,Fl::Framework::Access::Permission,Class] :permission The permission
    #  to request in order to complete the operation.
    #  See {Fl::Framework::Access::Helper.permission_name}.
    #  Defaults to {Fl::Framework::Access::Permission::Write::NAME}.
    # @option opts [Object] :context The context to pass to the access checker method {#class_allow_op?}.
    #  The special value **:params** (a Symbol named **params**) indicates that the create parameters are
    #  to be passed as the context.
    #  Defaults to **:params**.
    #
    # @return [Array] Returns an array containing two elements:
    #
    #  0. The target list object (an instance of {Fl::Framework::List::List}).
    #  1. The list item returned by the `add_object` call; this is an instance of
    #     {Fl::Framework::List::ListItem}.

    def add_object(opts = {})
      list = nil
      li = nil
      
      begin
        p = (opts[:params]) ? opts[:params].to_h : add_object_params(self.params).to_h
        op = (opts[:permission]) ? opts[:permission] : Fl::Framework::Access::Permission::Write::NAME
        #ctx = if opts.has_key?(:context)
        #        (opts[:context] == :params) ? p : opts[:context]
        #      else
        # This is equivalent to setting the default to :params
        #        p
        #      end
        idname = (opts[:idname]) ? opts[:idname].to_sym : :id

        list = get_and_check(op, idname)
        if list && success?
          rs = verify_captcha(opts[:captcha], p)
          if rs['success']
            li = list.add_object(p[:listed_object], p[:owner], p[:name])
          else
            li = nil
          end
        else
          li = nil
        end
      rescue => x
        set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY, x.message)
      end


      [ list, li ]
    end

    protected

    # Build a query to list instances of Fl::Framework::List::List.
    # This method makes a call to the class method `build_query`, which you will have to define.
    #
    # @param query_opts [Hash] A hash of query options.
    #
    # @return [ActiveRecord::Relation, nil] Returns an instance of ActiveRecord::Relation, or `nil`
    #  on error.

    def index_query(query_opts = {})
      Fl::Framework::List::List.build_query(query_opts)
    end

    private
  
    def add_object_params(p = nil)
      pp = strong_params(p).fetch(:fl_framework_list, {}).permit(:listed_object, :owner, :name)

      # we execute this statement to trigger an exception if :listed_object is missing
      rp = pp.require(:listed_object)
      
      pp
    end
  end
end
