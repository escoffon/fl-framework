require 'fl/framework/list'
require 'fl/framework/service/base'

module Fl::Framework::Service
  # Service object for list items.

  class ListItem < Fl::Framework::Service::Base
    self.model_class = Fl::Framework::List::ListItem

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the create parameters.

    def create_params(p = nil)
      # if :list_id is present in the params, it overrides the value of :list.
      # this supports nested list item controllers.
      
      sp = strong_params(p)
      np = sp.require(:fl_framework_list_item).permit(:list, :listed_object, :owner, :name,
                                                      :readonly_state, :state, :state_note)
      np[:list] = "#{Fl::Framework::List::List.name}/#{sp[:list_id]}" if sp.has_key?(:list_id)
      np      
    end

    # Get update parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the update parameters
    #  subset. if `nil`, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.

    def update_params(p = nil)
      strong_params(p).require(:fl_framework_list_item).permit(:owner,
                                                               :name, :readonly_state, :state, :state_note)
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
      Fl::Framework::List::ListItem.build_query(query_opts)
    end

    private
  end
end
