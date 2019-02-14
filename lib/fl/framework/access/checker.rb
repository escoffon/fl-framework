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
    # @param permission [Symbol,String,Fl::Framework::Access::Permission] The requested permission;
    #  this is usually the name of a permission registered with the permission registry, but it could
    #  also be passed as a permission instance.
    # @param actor [Object] The actor requesting *permission*.
    # @param asset [Object] The target of the request (the asset for which *permission* is requested).
    # @param context [any] The context in which to do the check; this is arbitrary data to pass to the
    #  checker parameter.
    #
    # @return [Symbol,nil,Boolean] An access check method is expected to return a symbol containing the
    #  name of the granted permission if access rights were granted.
    #  Note that the returned value may be different from *permission* if the permission is granted through
    #  forwarding (for example, if the request was for **:write** and it was granted because of a
    #  **:edit** permission).
    #  It should return `nil` if access grants were not granted.
    #  Under some conditions, it may elect to return `false` to indicate that there was some kind of error
    #  when checking for access; a `false` return value indicates that access rights were not granted,
    #  and it *must* be interpreted as such.

    def access_check(permission, actor, asset, context = nil)
      return nil
    end
  end
end