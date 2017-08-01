module Fl::Framework::Controller
  # Mixin module to add utilities methods (helpers).

  module Helper
    protected

    # Create a copy of a hash where all keys have been converted to symbols.
    # The operation is applied recursively to all values that are also keys.
    # Additionally, the *:id* key (if present) and any key that ends with +_id+ are copied to a key with the
    # same name, prepended by an underscore; for example, *:id* is copied to *:_id* and *:user_id* to
    # *:_user_id*.
    #
    # This method is typically used to normalize the +params+ value.
    #
    # @param h [Hash] The hash to normalize.
    #
    # @return [Hash] Returns a new hash where all keys have been converted to symbols. This operation
    #  is applied recursively to hash values.

    def normalize_params(h = nil)
      h = params unless h.is_a?(Hash)
      hn = {}
      re = /.+_id$/i
    
      h.each do |hk, hv|
        case hv
        when ActionController::Parameters
          hv = normalize_params(hv.to_h)
        when Hash
          hv = normalize_params(hv)
        end

        hn[hk.to_sym] = hv
        shk = hk.to_s
        hn["_#{shk}".to_sym] = (hv.is_a?(String) ? hv.dup : hv) if (shk == 'id') || (shk =~ re)
      end

      hn
    end

    # Get the pagination parameters.
    # Looks up the *:_pg* key in +params+ and returns the permitted values.
    #
    # @return [ActionController::Parameters] Returns the permitted pagination parameters, which are:
    # - *:_s* The page size.
    # - *:_p* The starting page (the first page is 1).
    # - *:_c* The count of items returned by the query. This is typically not used when generating
    #   query parameters, but rather is returned by the query.

    def pagination_params()
      params.fetch(:_pg, {}).permit(:_s, :_p, :_c)
    end

    # Hash support: returns a hash representation of an object, for the current user.
    #
    # @param obj [Object] The object whose +to_hash+ method to call. The object should have included
    #  {Fl::ModelHash}.
    # @param hash_opts [Hash] The hashing options for +to_hash+.
    #
    # @return [Hash] Returns a hash representation of _obj_.

    def hash_one_object(obj, hash_opts)
      obj.to_hash(current_user, hash_opts)
    end

    # Hash support: returns an array of hash representations of objects, for the current user.
    #
    # @param ary [Array<Object>] The array of objects whose +to_hash+ method to call. The objects should have
    #  included {Fl::ModelHash}.
    # @param hash_opts [Hash] The hashing options for +to_hash+.
    #
    # @return [Array<Hash>] Returns an array of hash representations of _ary_.

    def hash_objects(ary, hash_opts)
      ary.map { |r| r.to_hash(current_user, hash_opts) }
    end

    # Set the timezone based on the current user (if any)

    def set_timezone()
      current_tz = Time.zone
      if logged_in?
        Time.zone = current_user.timezone
      end
    ensure
      Time.zone = current_tz
    end

    # Add a message to the flash, converting to an array if needed.
    #
    # @param type A symbol containing the flash key (:notice, :error, and so on).
    # @param msg A value to add to the flash; although this is typically a string, it really need not be.

    def add_flash_message(type, msg)
      if flash[type].nil?
        flash[type] = msg
      elsif flash[type].is_a?(Array)
        if msg.is_a?(Array)
          msg.each { |m| flash[type] << m }
        else
          flash[type] << msg
        end
      else
        f = [ flash[type] ]
        if msg.is_a?(Array)
          msg.each { |m| f << m }
        else
          f << msg
        end
        flash[type] = f
      end
    end

    # Get the response format.
    #
    # @return Returns the response format from the :format key in the @c params hash; if no :format key,
    #  returns :html.

    def response_format()
      params.has_key?(:format) ? params[:format] : :html
    end

    # Check if we are displaying HTML.
    #
    # @return Returns true if the response is expected to display HTML, false otherwise.

    def html_format?()
      self.response_format == :html
    end
  end
end
