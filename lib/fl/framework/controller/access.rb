module Fl::Framework::Controller
  # Mixin module to add access control methods..

  module Access
    protected

    # Wrapper around the service {Fl::Framework::Service::Base#class_allow_op?} method.
    # Calls the service method and then checks if it was successful; if not, calls {#error_response}
    # and returns +false+.
    # On success, returns +true+.
    #
    # @param srv [Fl::Framework::Service::Base] A service object to use for the get and check call.
    # @param op [Symbol] The operation.
    #
    # @return [Boolean] Returns +true+ if the service grants permission _op_, +false+ otherwise.

    def class_allow_op?(srv, op)
      unless srv.class_allow_op?(op)
        error_response(generate_error_info(srv))
        false
      else
        true
      end
    end

    # Wrapper around the service {Fl::Framework::Service::Base#get_and_check} method.
    # Calls the service method and then checks if it was successful; if not, calls {#error_response}
    # and returns +false+.
    # On success, returns +true+.
    # Either way, the object that was looked up (if any) is placed in the instance variable named _vname_.
    #
    # @param srv [Fl::Framework::Service::Base] A service object to use for the get and check call.
    # @param op [Symbol] The operation for the check.
    # @param vname [String, Symbol] The name of the instance variable to set (this includes the starting @).
    # @param [Symbol] idname The name of the key in _params_ that contains the object identifier.
    #  A +nil+ value defaults to +:id+.
    # @param params [Hash] The parameters to use for the get and check; this value is passed to
    #  the {Fl::Framework::Service::Base#get_and_check} method as is.
    #
    # @return [Boolean] Returns +true+ on success, +false+ on failure.

    def get_and_check(srv, op, vname, idname = nil, params = nil)
      obj = srv.get_and_check(op, idname, params)
      self.instance_variable_set(vname, obj)
      unless srv.success?
        error_response(generate_error_info(srv, obj))
        return false
      end

      true
    end
  end
end
