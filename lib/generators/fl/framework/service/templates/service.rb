<%= @service_c[:open_module] %>
  # The service object for <%=@data_c[:full_name]%>.

  class <%=@service_c[:name]%> < Fl::Framework::Service::Base
    self.model_class = <%=@data_c[:full_name]%>

    # Get create parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the create parameters
    #  subset. if +nil+, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.

    def create_params(p = nil)
      strong_params(p).require(:<%=@data_c[:full_name].underscore.gsub('/', '_')%>).permit(:param1, :param2)
    end

    # Get update parameters.
    #
    # @param p [Hash,ActionController::Parameters] The parameters from which to extract the update parameters
    #  subset. if +nil+, use {#params}.
    #
    # @return [ActionController::Parameters] Returns the update parameters.

    def update_params(p = nil)
      strong_params(p).require(:<%=@data_c[:full_name].underscore.gsub('/', '_')%>).permit(:param1, :param2)
    end

    protected

    # Build a query to list instances of <%=@data_c[:full_name]%>.
    # This method makes a call to the class method `build_query`, which you will have to define.
    #
    # @param query_opts [Hash] A hash of query options.
    #
    # @return [ActiveRecord::Relation, nil] Returns an instance of ActiveRecord::Relation, or +nil+
    #  on error.

    def index_query(query_opts = {})
      <%=@data_c[:full_name]%>.build_query(query_opts)
    end
  end
<%= @service_c[:close_module] %>
