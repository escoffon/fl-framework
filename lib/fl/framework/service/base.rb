module Fl::Framework::Service
  # Base class for service object.
  # A service object implements the processing (business) logic of application components; it typically
  # provides the glue between a controller and the underlying data layer.
  #
  # Service objects include access checks for the various operations, so that controllers do not have to
  # perform explicit checks; this streamlines the controller code. Access checking can be turned off
  # by setting the configuration parameter +disable_access_check+ to true.
  # Also, if the service's {#model_class} does not respond to +permission?+, no access control is performed.

  class Base
    # The service actor.
    # @return [Object] Returns the _actor_ parameter that was passed to the initializer.
    attr_reader :actor

    # The service parameters.
    # @return [Hash] Returns the _params_ parameter that was passed to the initializer.
    attr_reader :params

    # The service controller.
    # @return [ActionController::Base] Returns the _controller_ parameter that was passed to the initializer.
    attr_reader :controller

    # Initializer.
    #
    # @param actor [Object] The actor (typically an instance of {Fl::Core::Actor}, and more specifically
    #  a {Fl::Core::User}) on whose behalf the service operates. It may be +nil+.
    # @param params [Hash] Processing parameters; this is typically the +params+ hash from a controller.
    #  On Rails 5, the controller will likely be passed an ActionController::Parameters instance instead;
    #  in that case, the parameters are converted to a hash.
    # @param controller [ActionController::Base] The controller (if any) that created the service object;
    #  this parameter gives access to the request context.
    # @param cfg [Hash] Configuration options.
    # @option cfg [Boolean] :disable_access_checks Controls the access checks: set it to +true+ to
    #  disable access checking. The default value is +false+.
    #
    # @raise Raises an exception if the target model class has not been defined.

    def initialize(actor, params = {}, controller = nil, cfg = {})
#      @actor = (actor.is_a?(Fl::Core::Actor)) ? actor : nil
      @actor = actor
      @params = normalize_params(params)
      @controller = (controller.is_a?(ActionController::Base)) ? controller : nil

      raise "please define a target model class for #{self.class.name}" unless self.class.model_class

      @_has_instance_permission = (self.model_class.instance_methods.include?(:permission?)) ? true : false
      @_has_class_permission = (self.model_class.methods.include?(:permission?)) ? true : false

      @_disable_access_checks = (cfg[:disable_access_checks]) ? true : false
    end

    # @!attribute [r] localization_prefix
    # The localization prefix.
    # This string is prefixed to localization strings; it is obtained from the class name by replacing 
    # +::+ with +.+ and then calling +underscore+ on the result.
    # So for example the localization prefix for class +Fl::Framework::Service::Asset::MyAsset+ is
    # +fl.framework.service.asset.my_asset+.
    #
    # @return [String] Returns the localization prefix as described above.

    def localization_prefix()
      unless @localization_prefix
        @localization_prefix = self.class.name.gsub('::', '.').underscore
      end
      @localization_prefix
    end

    # @!attribute [r] model_class
    # The target model class.
    # Wraps a call to {.model_class}.
    #
    # @return [Class] Returns the model class.

    def model_class()
      self.class.model_class
    end

    # @!attribute [r] status
    # The status of the last call made.
    #
    # @return [Hash] Returns a hash containing the status of the last operation performed.
    #  The following keys may be present:
    #  - *:status* A symbol describing the status of the call; see the constants defined
    #    in {Fl::Framework::Service}. A value other than {Fl::Framework::Service::OK} implies that the call failed.
    #  - *:code* An integer code associated with the error. This key is currently not generated.
    #  - A hash containing information about the failure (will not be present on success).
    #    This hash is named the same as the value for *:status*; for example, if *:status* is
    #    {Fl::Framework::Service::FORBIDDEN}, the key +:forbidden+ is present in the status value.
    #    This hash contains the following keys:
    #    - *:message* A string containing a localized message related to the failure.
    #    - *:details* Additional information about the failure; for example, on operations that manage
    #      an object, this may contain the object's +errors.messages+.

    def status()
      @status.dup
    end

    # Clear the status.
    # The method sets the service in the success status.

    def clear_status()
      @status = { status: Fl::Framework::Service::OK }
    end

    # Set the status.
    # The message is placed in the hash by the same name as _status_, under the +:message+ key.
    # For example, a call to
    #   srv.set_status(Fl::Framework::Service::FORBIDDEN, 'not allowed')
    # sets up the status as follows:
    #   {
    #     status: Fl::Framework::Service::FORBIDDEN,
    #     Fl::Framework::Service::FORBIDDEN.to_sym: {
    #       message: 'not allowed'
    #     }
    #   }
    #
    # @param status [Symbol] The status value (for example, {Fl::Framework::Service::FORBIDDEN}).
    # @param msg [String] A message to associate with the status.
    # @param details [Hash] Additional information to place in the *:details* for the error.

    def set_status(status, msg, details = nil)
      @status = {} unless @status.is_a?(Hash)
      @status[:status] = status
      m = @status[status.to_sym] || {}
      m[:message] = msg
      m[:details] = details if details
      @status[status.to_sym] = m
    end

    # @!attribute [r] success?
    # Checks if the status indicates success.
    #
    # @return [Boolean, nil] Returns +true+ if the current status contains a {Fl::Framework::Service::OK} value in the
    #  +:status+ key, +false+ otherwise. If there is no +:status+ key, returns +nil+.

    def success?()
      return nil unless @status && @status.has_key?(:status)
      (@status[:status] == Fl::Framework::Service::OK) ? true : false
    end

    # Check if the class object associated with the service allows an operation.
    # This check is done for operation triggered by the class object, like running the +:index+
    # or +:create+ action.
    #
    # @param op [Symbol] The operation.
    # @param ctx [Object] The context to pass to the +permission?+ method.
    #
    # @return [Boolean] Returns +true+ if the service's {#actor} is granted permission _op_,
    #  +false+ otherwise.
    #  If the {#model_class} does not respond to +permission?+, or if permission checking is disabled,
    #  +true+ is returned.

    def class_allow_op?(op, ctx = nil)
      if do_access_checks?(self.model_class)
        if !self.model_class.permission?(self.actor, op, ctx)
          self.set_status(Fl::Framework::Service::FORBIDDEN,
                          I18n.tx(localization_key('forbidden'), id: self.params[:id], op: op) )
          return false
        end
      end

      self.clear_status
      true
    end

    # Check if an object allows an operation.
    # This check is done for operation triggered by a class instance, like running the +:show+
    # or +:update+ action.
    #
    # @param obj [Object] The object to check; this is typically an instance of {#model_class}.
    # @param op [Symbol] The operation.
    # @param ctx [Object] The context to pass to the +permission?+ method.
    #
    # @return [Boolean] Returns +true+ if the service's {#actor} is granted permission _op_,
    #  +false+ otherwise.
    #  If the _obj_ does not respond to +permission?+, or if permission checking is disabled,
    #  +true+ is returned.

    def allow_op?(obj, op, ctx = nil)
      if do_access_checks?(obj)
        if !obj.permission?(self.actor, op, ctx)
          self.set_status(Fl::Framework::Service::FORBIDDEN,
                          I18n.tx(localization_key('forbidden'), id: self.params[:id], op: op) )
          return false
        end
      end

      self.clear_status
      true
    end

    # Look up an object in the database, and check if the service's actor has permissions on it.
    # This method uses the +:id+ entry in the {#params} to look up the object in the database
    # (using the target model class as the context for +find+).
    # If it does not find the object, it sets the status to {Fl::Framework::Service::NOT_FOUND} and returns +nil+.
    # If it finds the object, it then calls {Fl::Access::Access::InstanceMethods#permission?} to
    # confirm that the actor has _op_ access to the object.
    # If the permission call fails, it sets the status to {Fl::Framework::Service::FORBIDDEN} and returns the object.
    # Otherwise, it sets the status to {Fl::Framework::Service::OK} and returns the object.
    #
    # @param [Symbol] op The operation for which to request permission. If +nil+, no access check is performed
    #  and the call is the equivalent of a simple database lookup.
    # @param [Symbol] idname The name of the key in _params_ that contains the object identifier.
    #  A +nil+ value defaults to +:id+.
    # @param [Hash] params The parameters where to look up the +:id+ key used to fetch the object.
    #  If +nil+, use the _params_ value that was passed to the constructor.
    #
    # @return [Object, nil] Returns an object, or +nil+. Note that a non-nil return value is not a guarantee
    #  that the check operation succeded.

    def get_and_check(op, idname = nil, params = nil)
      idname = idname || :id
      params = params || self.params

      begin
        obj = self.model_class.find(params[idname])
      rescue => ex
        self.set_status(Fl::Framework::Service::NOT_FOUND,
                        I18n.tx(localization_key('not_found'), id: params[idname]))
        return nil
      end

      self.clear_status if allow_op?(obj, op)
      obj
    end

    # Create an instance of the model class.
    # This method attempts to create and save an instance of the model class; if either operation fails,
    # it sets the status to {Fl::Framework::Service::UNPROCESSBLE_ENTITY} and loads a message and the +:details+
    # key in the error status from the object's +errors+. 
    #
    # The method calls {#class_allow_op?} for {Fl::Access::Grants::CREATE} to confirm that the service's
    # _actor_ has permission to create objects. If the permission is not granted, +nil+ is returned.
    #
    # @param params [Hash] The parameters to pass to the object's constructor.
    #
    # @return [Object, nil] Returns an instance of the {#model_class}. Note that a non-nil return value
    #  does not indicate that the call was successful; for that, you should call {#success?} or check if
    #  the instance is valid.

    def create(params)
      if class_allow_op?(Fl::Access::Grants::CREATE)
        obj = self.model_class.new(params)
        unless obj.save
          self.set_status(Fl::Framework::Service::UNPROCESSABLE_ENTITY,
                          I18n.tx(localization_key('creation_failure')),
                          (obj) ? obj.errors.messages : nil)
        end
        obj
      else
        nil
      end
    end

    protected

    # @!visibility private
    QUERY_BACKSTOPS = {
      :offset => 0,
      :limit => 20,
      :order => 'updated_at DESC'
    }

    # @!visibility private
    QUERY_INT_PARAMS = [ :offset, :limit ]
    # @!visibility private
    QUERY_DATETIME_PARAMS = [ :updated_since, :created_since, :updated_before, :created_before ]

    public

    # Initialize the query options for the :index action.
    # This methods merges the contents of the *:_q* and *:_pg* keys in _pars_ into the default backstops.
    # It also converts some values to a canonical form (for example, integer-valued options are converted
    # to integer values).
    #
    # The value of the *:_q* key is a hash of options for the :index action. The value of the *:_pg* key is
    # a hash containing pagination control values:
    # - *:_s* is the page size (the number of items to return); a negative value means to return all items.
    # - *:_p* is the 1-based index of the page to return; the first page is at index 1.
    #
    # The method builds the query options as follows:
    # 1. Set up default values for the query options from _defs_.
    # 2. Look up *:_q* and *:_pg* from _pars_ or from the {#params} if _pars_ is not a hash. 
    # 3. The values in *:_pg* (if any) are used to initialize the values for *:offset* and *:limit* in the query
    #    options: *:limit* is the value of the *:_s* key, and *:offset* is <tt>(_pg[_p] - 1) * :limit</tt>.
    # 4. Merge the values in *_q* into the query options; *:offset* and *:limit* override the values
    #    from the previous step. Aadditionally, if *:limit* is negative, then *:_pg* is ignored; for example,
    #    if *:_s* is 4, *:_pg* is 2, *:limit* is -1, and *:offset* is 4, then the new value of *:_pg*
    #    is <tt>{ _s: -1, _p: 1 }</tt>. See {#pagination_controls}.
    # 5. If the value of *:limit* is negative, *:limit* is removed from the query options.
    #
    # @param defs [Hash] A hash of default values for the options, which override the following backstops:
    #  - *:offset* is 0.
    #  - *:limit* is 20. If the value in _defs_ is -1, *:limit* is not placed in the query options.
    #  - *:order* is <tt>updated_at DESC</tt>.
    #  Any other keys in _defs_ provide the backstop, and the method looks up an overriding
    #  value in the *_q* key of _pars_.
    # @param pars [Hash] The submission query parameters. If +nil+, the {#params} value is used.
    #
    # @return [Hash] Returns a hash of query options.

    def init_query_opts(defs = {}, pars = nil)
      sdefs = {}
      if defs.is_a?(Hash)
        defs.each { |k, v| sdefs[k.to_sym] = v }
      end
      opts = QUERY_BACKSTOPS.merge(sdefs)

      xp = (pars.is_a?(Hash)) ? pars : self.params
      _q = (xp[:_q].is_a?(Hash)) ? normalize_params(xp[:_q]) : {}
      _pg = (xp[:_pg].is_a?(Hash)) ? normalize_params(xp[:_pg]) : {}
      
      opts[:limit] = _pg[:_s].to_i if _pg.has_key?(:_s)
      opts[:offset] = ((_pg[:_p].to_i - 1) * opts[:limit]) if _pg.has_key?(:_p)
      opts[:offset] = 0 if opts[:offset] < 0

      _q.each do |k, v|
        sk = k.to_sym
        if QUERY_INT_PARAMS.include?(sk)
          opts[sk] = v.to_i
        elsif QUERY_DATETIME_PARAMS.include?(sk)
          opts[sk] = ((v =~ /^[0-9]+$/).nil?) ? v : v.to_i
        else
          opts[sk] = v
        end
      end

      if _q.has_key?(:order)
        case _q[:order]
        when Array
          opts[:order] = _q[:order].join(', ')
        else
          opts[:order] = _q[:order]
        end
      end

      opts.delete(:limit) if opts[:limit] < 0

      opts
    end

    # Generate pagination control data for the next page in an :index query.
    # This methods generates a pagination control hash from the values of the options to an :index query.
    #
    # The method builds the pagination controls as follows:
    # 1. Initialize with the values from *:_pg* in _opts_, if any.
    # 2. Set the value of *:_c* to the length of the _results_ array, or to 0 if _results_ is +nil+.
    # 3. If _opts_ does not have a *:limit* value, set *:_s* to -1 and *:_p* to 1, since we cannot determine
    #    the page size and therefore calculate a starting page from the *:offset* option.
    # 4. Otherwise, set *:_s* to the value of *:limit* in _opts_, and *:_p* to the next page, based on the
    #    value of *:offset* and *:limit*.
    # Note that setting *:offset* or *:limit* (or both) in _opts_ may cause the pagination controls to be
    # inaccurate. Clients that use these two options should not rely on the pagination controls.
    #
    # @param results [Array, nil] An array containing the results from the query.
    # @param opts [Hash] A hash containing query options.
    # @param pars [Hash] The submission query parameters. If +nil+, the controller's +params+ value is used.
    #
    # @return [Hash] Returns a hash containing the pagination controls: *:_s* is the page size, *:_p* is the
    #  next page to fetch.

    def pagination_controls(results = nil, opts = {}, pars = nil)
      xp = (pars.is_a?(Hash)) ? pars : params
      _pg = (xp[:_pg].is_a?(Hash)) ? normalize_params(xp[:_pg]) : {}

      npg = {}
      npg[:_c] = (results.is_a?(Array)) ? results.count : 0
      npg[:_s] = _pg[:_s].to_i if _pg.has_key?(:_s)
      npg[:_p] = _pg[:_p].to_i if _pg.has_key?(:_p)

      if opts.has_key?(:limit) && (opts[:limit].to_i > 0)
        npg[:_s] = opts[:limit].to_i
        if opts.has_key?(:offset)
          npg[:_p] = ((opts[:offset].to_i + npg[:_s]) / npg[:_s]) + 1
          npg[:_p] = 1 if npg[:_p] < 1
        else
          npg[:_p] = 1
        end
      else
        npg[:_s] = -1
        npg[:_p] = 1
      end

      npg
    end

    protected

    # Create a copy of a hash where all keys have been converted to symbols.
    # The operation is applied recursively to all values that are also hashes.
    #
    # This method is typically used to normalize the +params+ value.
    #
    # @param h [Hash] The hash to normalize; this may also be an instance of ActionController::Parameters.
    #
    # @return [Hash] Returns a new hash where all keys have been converted to symbols. This operation
    #  is applied recursively to hash values.

    def normalize_params(h)
      hn = {}
      
      h.each do |hk, hv|
        hv = normalize_params(hv) if hv.is_a?(Hash) || hv.is_a?(ActionController::Parameters)
        hn[hk.to_sym] = hv
      end

      hn
    end

    # Check that access checks are enabled and supported.
    #
    # @param obj [Object, Class, nil] The object that makes the +permission?+ call; if +nil+, the
    #  {#model_class} is used.
    #
    # @return [Boolean] Returns +true+ if access checks are enabled, and _obj_ responds to +permission?+;
    #  otherwise, it returns +false+.

    def do_access_checks?(obj = nil)
      obj = self.model_class if obj.nil?
      (@_disable_access_checks || !obj.respond_to?(:permission?)) ? false : true
    end

    # Build a lookup key in the message catalog.
    #
    # @param key [String] The partial key.
    #
    # @return [String] Returns a key in the message catalog by prepending _key_ with the localization
    #  prefix.

    def localization_key(key)
      localization_prefix + '.' + key
    end

    # @!visibility private
    @_model_class = nil

    # Set the target model class.
    # The service manages instances of this class. For example, the {#get_and_check} method uses this
    # class to look up an object in the database by object identifier (i.e. it calls something like
    #   self.class.model_class.find(self.params[:id])
    # to look up an object of the appropriate class.
    #
    # Subclasses must call this method in the class definition, for example:
    #   class MyService < Fl::Framework::Service::Base
    #     self.model_class = Fl::MyModel
    #   end
    # The initializer will check that the target model class has been defined.
    #
    # @param klass [Class] The target model class.

    def self.model_class=(klass)
      @_model_class = klass
    end

    # The target model class.
    # See {.model_class=}.
    #
    # @return [Class] Returns the model class.

    def self.model_class()
      @_model_class
    end
  end
end
