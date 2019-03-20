require 'fl/framework/list'
require 'fl/framework/service/base'

module Fl::Framework::Service::Actor
  # Service object for list items.

  class GroupMember < Fl::Framework::Service::Base
    self.model_class = Fl::Framework::Actor::GroupMember

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def create_params(p = nil)
      # if :group_id is present in the params, it overrides the value of :group.
      # this supports nested list item controllers.
      
      sp = strong_params(p)
      np = sp.require(:fl_framework_actor_group_member).permit(:title, :note, :group, :actor)
      np[:group] = Fl::Framework::Actor::Group.fingerprint(sp[:group_id]) if sp.has_key?(:group_id)
      np      
    end

    # Get update parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the update parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.

    def update_params(p = nil)
      strong_params(p).require(:fl_framework_actor_group_member).permit(:title, :note)
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

    protected

    # Build a query to list instances of Fl::Framework::List::List.
    # This method makes a call to the class method `build_query`, which you will have to define.
    #
    # @param query_opts [Hash] A hash of query options.
    #
    # @return [ActiveRecord::Relation, nil] Returns an instance of ActiveRecord::Relation, or `nil`
    #  on error.

    def index_query(query_opts = {})
      Fl::Framework::Actor::GroupMember.build_query(query_opts)
    end

    private
  end
end
