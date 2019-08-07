module Fl::Framework::Access
  # The base class for permission checkers.
  # A permission checker implements an algorithm for checking if an actor has been granted a requested
  # permission on an object (which will be referred to as an *asset*).
  #
  # Note that checker methods typically are not invoked directly, but rather through methods that
  # were injected by the {Fl::Framework::Access::Access::ClassMacros#has_access_control} macro.
  
  class Checker
    # Initializer.

    def initialize()
      super()
    end

    # Configure the including class.
    # The access control macro {Fl::Framework::Access::Access::ClassMacros#has_access_control} calls
    # this method in its implementation.
    # Use it to perform checker-specific configuration of the including class (for example, to inject
    # instance methods to manage access rights); see {Fl::Framework::Asset::AccessChecker} for an
    # example.
    #
    # @param base [Class] The class object in whose context the `has_access_control` macro is executed.

    def configure(base)
    end
    
    # Run an access check.
    # This method implements the algorithm to check if *actor* has been granted permission *permission*
    # on object *asset*. For example, to check if user `u1` has **:read** access to file asset *a*,
    # you call this method as follows.
    #
    # ```
    # u1 = get_user()
    # a = get_file_asset()
    # c = get_checker_instance()
    # granted = c.access_check(:read, u1, a)
    # ```
    #
    # The default implementation is rather restrictive: it simply returns `nil` to indicate that
    # no access has been granted. Subclasses are expected to override it.
    #
    # @param permission [Symbol,String,Fl::Framework::Access::Permission,Class] The requested permission.
    #  See {Fl::Framework::Access::Helper.permission_name}.
    # @param actor [Object] The actor requesting *permission*.
    # @param asset [Object] The target of the request (the asset for which *permission* is requested).
    # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
    #  checker parameter.
    #
    # @return [Boolean,nil] An access check method is expected to return a boolean value `true` if access
    #  rights were granted, and `false` if access rights were denied.
    #  Under some conditions, it may elect to return `nil` to indicate that there was some kind of error
    #  when checking for access; a `nil` return value indicates that access rights were not granted,
    #  and it *must* be interpreted as such.

    def access_check(permission, actor, asset, context = nil)
      return false
    end

    protected
    
    # Get the name of a permission.
    # This is just a wrapper for {Fl::Framework::Access::Helper.permission_name}, provided here as
    # a convenience for subclasses.
    #
    # @param permission [Symbol,String,Fl::Framework::Access::Permission,Class] The permission whose name
    #  to get.
    #
    # @return [Symbol,nil] Returns the permission name if it can resolve it; otherwise, it returns `nil`.
    
    def permission_name(permission)
      Fl::Framework::Access::Helper.permission_name(permission)
    end
  end
end
